package hookhandler

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/foden303/harness/go/internal/gitport"
)

// EmitAgentTrace is the Go port of emit-agent-trace.js.
// It appends a trace record to agent-trace.jsonl in the PostToolUse hook.
// If OTEL_EXPORTER_OTLP_ENDPOINT is set, it POSTs an OTel Span asynchronously.
//
// Source: scripts/emit-agent-trace.js
type EmitAgentTrace struct {
	// RepoRoot specifies the repository root.
	// If empty, auto-detected from cwd.
	RepoRoot string
	// StateDir specifies the location of the trace file.
	// If empty, uses RepoRoot/.claude/state.
	StateDir string
	// MaxFileSize is the file rotation threshold (bytes). Default 10MB.
	MaxFileSize int64
	// MaxGenerations is the number of rotation generations. Default 3.
	MaxGenerations int
	// HTTPClient is the HTTP client for OTel export (replaceable for tests).
	HTTPClient *http.Client
	// Now is a function returning the current time (for tests).
	Now func() string
}

// traceVersion is the agent-trace version.
const traceVersion = "0.3.0"

// eatMaxFileSizeDefault is the default file size limit (10MB).
const eatMaxFileSizeDefault int64 = 10 * 1024 * 1024

// eatMaxGenerationsDefault is the default number of rotation generations.
const eatMaxGenerationsDefault = 3

// traceCacheTTL is the cache TTL for project metadata.
const traceCacheTTL = 60 * time.Second

// vcsCacheTTL is the cache TTL for VCS information.
const vcsCacheTTL = 5 * time.Second

// traceRecord is a single record in agent-trace.jsonl.
type traceRecord struct {
	Version     string                 `json:"version"`
	ID          string                 `json:"id"`
	Timestamp   string                 `json:"timestamp"`
	Tool        string                 `json:"tool"`
	Files       []traceFile            `json:"files"`
	VCS         *traceVCS              `json:"vcs,omitempty"`
	Metadata    map[string]interface{} `json:"metadata"`
	Attribution *traceAttribution      `json:"attribution,omitempty"`
	Metrics     *traceMetrics          `json:"metrics,omitempty"`
}

// traceFile is file information operated on by a tool.
type traceFile struct {
	Path   string `json:"path"`
	Action string `json:"action"`
	Range  string `json:"range"`
}

// traceVCS is VCS (Git) information.
type traceVCS struct {
	Revision string `json:"revision"`
	Branch   string `json:"branch"`
	Dirty    bool   `json:"dirty"`
}

// traceAttribution is plugin attribution information.
type traceAttribution struct {
	Plugin  string `json:"plugin"`
	Version string `json:"version"`
	License string `json:"license,omitempty"`
	Author  string `json:"author,omitempty"`
}

// traceMetrics is metrics information for the Task tool.
type traceMetrics struct {
	TokenCount *int64   `json:"tokenCount,omitempty"`
	ToolUses   *int64   `json:"toolUses,omitempty"`
	Duration   *float64 `json:"duration,omitempty"`
}

// tracerCache is a tracer-level cache.
type tracerCache struct {
	mu sync.Mutex

	// Project metadata cache
	projMeta     map[string]string
	projMetaTime time.Time

	// VCS cache
	vcsInfo *traceVCS
	vcsTime time.Time

	// Attribution cache
	attr     *traceAttribution
	attrTime time.Time
}

// Global cache (shared within the process)
var eatCache = &tracerCache{}

// Handle builds a trace record from PostToolUse env vars and appends it to JSONL.
// r is unused (info is obtained from env vars).
func (e *EmitAgentTrace) Handle(r io.Reader, w io.Writer) error {
	toolName := os.Getenv("CLAUDE_TOOL_NAME")
	toolInput := os.Getenv("CLAUDE_TOOL_INPUT")
	toolResult := os.Getenv("CLAUDE_TOOL_RESULT")
	sessionID := os.Getenv("CLAUDE_SESSION_ID")

	// Only Edit / Write / Task are targeted
	if !eatIsSupportedTool(toolName) {
		return nil
	}

	repoRoot := e.RepoRoot
	if repoRoot == "" {
		repoRoot = pcsFindRepoRoot()
	}

	files := e.parseToolInput(toolName, toolInput, repoRoot)
	if len(files) == 0 && toolName != "Task" {
		return nil
	}

	// Convert paths to relative paths
	for i, f := range files {
		if filepath.IsAbs(f.Path) {
			rel, err := filepath.Rel(repoRoot, f.Path)
			if err == nil {
				files[i].Path = rel
			}
		}
	}

	rec := traceRecord{
		Version:   traceVersion,
		ID:        eatGenerateUUID(),
		Timestamp: e.getNow(),
		Tool:      toolName,
		Files:     files,
		Metadata:  make(map[string]interface{}),
	}

	if sessionID != "" {
		rec.Metadata["sessionId"] = sessionID
	}

	// VCS information
	if vcs := e.getVCSInfo(); vcs != nil {
		rec.VCS = vcs
	}

	// Project metadata
	meta := e.getProjectMetadata(repoRoot)
	for k, v := range meta {
		rec.Metadata[k] = v
	}

	// Attribution
	if attr := e.getAttribution(); attr != nil {
		rec.Attribution = attr
	}

	// Task-tool-only fields
	if toolName == "Task" {
		if m := e.extractTaskMetrics(toolResult); m != nil {
			rec.Metrics = m
		}
		e.extractTaskMetadata(toolInput, &rec)
	}

	stateDir := e.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(repoRoot, ".claude", "state")
	}
	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")

	if err := e.appendTrace(repoRoot, stateDir, tracePath, &rec); err != nil {
		// Silently ignore trace failures (do not block tool execution)
		_, _ = fmt.Fprintf(os.Stderr, "[agent-trace] %v\n", err)
	}

	// OTel export (fire-and-forget).
	// Waiting on wg.Wait() caused a 3-second block when the collector was slow.
	// Since the JSONL write (the actual purpose) already completed synchronously in
	// appendTrace above, the OTel POST is left to a best-effort goroutine.
	// Environments without OTel (the majority) are unaffected.
	// In environments with OTel, the goroutine may be killed on process exit, but
	// this is "best-effort" behavior equivalent to the JS version's detached child process.
	if endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"); endpoint != "" {
		go e.emitOtelSpan(endpoint, &rec)
	}

	return nil
}

// appendTrace performs security checks and appends the trace.
func (e *EmitAgentTrace) appendTrace(repoRoot, stateDir, tracePath string, rec *traceRecord) error {
	claudeDir := filepath.Join(repoRoot, ".claude")

	// .claude symlink check
	if info, err := os.Lstat(claudeDir); err == nil && info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf(".claude symlink detected, refusing to write trace")
	}

	// stateDir creation and security check
	if info, err := os.Lstat(stateDir); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("stateDir is symlink, refusing to write trace")
		}
		_ = os.Chmod(stateDir, 0700)
	} else {
		if err := os.MkdirAll(stateDir, 0700); err != nil {
			return fmt.Errorf("creating stateDir: %w", err)
		}
	}

	// tracePath symlink check
	if info, err := os.Lstat(tracePath); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("tracePath is symlink, refusing to write trace")
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("tracePath is not a regular file")
		}
	}

	e.rotateIfNeeded(tracePath)

	line, err := json.Marshal(rec)
	if err != nil {
		return fmt.Errorf("marshaling trace record: %w", err)
	}

	f, err := os.OpenFile(tracePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return fmt.Errorf("opening trace file: %w", err)
	}
	defer f.Close()

	// Fix an existing file's permissions to 0600 (os.OpenFile's perm arg only applies on creation).
	// The JS version called fchmodSync after open.
	_ = f.Chmod(0600)

	// Verify the opened fd is a regular file
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() {
		return fmt.Errorf("opened fd is not a regular file")
	}

	if _, err := fmt.Fprintf(f, "%s\n", line); err != nil {
		return fmt.Errorf("writing trace: %w", err)
	}
	return nil
}

// rotateIfNeeded rotates the file when its size exceeds the limit.
func (e *EmitAgentTrace) rotateIfNeeded(tracePath string) {
	maxSize := e.MaxFileSize
	if maxSize == 0 {
		maxSize = eatMaxFileSizeDefault
	}
	maxGen := e.MaxGenerations
	if maxGen == 0 {
		maxGen = eatMaxGenerationsDefault
	}

	info, err := os.Stat(tracePath)
	if err != nil || info.Size() < maxSize {
		return
	}

	// Prevent concurrent rotation with a lock file
	lockPath := tracePath + ".lock"
	lockF, err := os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return // Another process is rotating
	}
	lockF.Close()
	defer os.Remove(lockPath)

	// Re-check size
	info, err = os.Stat(tracePath)
	if err != nil || info.Size() < maxSize {
		return
	}

	// Generation rotation
	for i := maxGen - 1; i >= 1; i-- {
		oldPath := fmt.Sprintf("%s.%d", tracePath, i)
		newPath := fmt.Sprintf("%s.%d", tracePath, i+1)
		if _, err := os.Stat(oldPath); err == nil {
			if i == maxGen-1 {
				_ = os.Remove(oldPath)
			} else {
				_ = os.Rename(oldPath, newPath)
			}
		}
	}
	_ = os.Rename(tracePath, tracePath+".1")
}

// parseToolInput extracts file information from tool input.
func (e *EmitAgentTrace) parseToolInput(toolName, toolInput, repoRoot string) []traceFile {
	if toolInput == "" {
		return nil
	}

	var input map[string]interface{}
	if err := json.Unmarshal([]byte(toolInput), &input); err != nil {
		return nil
	}

	var files []traceFile

	switch toolName {
	case "Edit":
		if fp, ok := input["file_path"].(string); ok && fp != "" {
			if eatIsPathWithinRepo(fp, repoRoot) {
				files = append(files, traceFile{Path: fp, Action: "modify", Range: "unknown"})
			}
		}
	case "Write":
		// At PostToolUse time the file is already written, so os.Stat always
		// succeeds and cannot distinguish create/modify. Decide based on tool_name.
		// Write = new creation, Edit/MultiEdit = modification of an existing file.
		if fp, ok := input["file_path"].(string); ok && fp != "" {
			if eatIsPathWithinRepo(fp, repoRoot) {
				files = append(files, traceFile{Path: fp, Action: "create", Range: "unknown"})
			}
		}
	case "MultiEdit":
		if fp, ok := input["file_path"].(string); ok && fp != "" {
			if eatIsPathWithinRepo(fp, repoRoot) {
				files = append(files, traceFile{Path: fp, Action: "modify", Range: "unknown"})
			}
		}
	}

	return files
}

// extractTaskMetadata extracts metadata from Task tool input.
func (e *EmitAgentTrace) extractTaskMetadata(toolInput string, rec *traceRecord) {
	if toolInput == "" {
		return
	}
	var input map[string]interface{}
	if err := json.Unmarshal([]byte(toolInput), &input); err != nil {
		return
	}
	if taskID, ok := input["task_id"].(string); ok && taskID != "" {
		rec.Metadata["taskId"] = taskID
	}
	if subagentType, ok := input["subagent_type"].(string); ok && subagentType != "" {
		rec.Metadata["subagentType"] = subagentType
		rec.Metadata["agentRole"] = eatNormalizeAgentRole(subagentType)
	} else if agentName, ok := input["agent_name"].(string); ok && agentName != "" {
		rec.Metadata["agentRole"] = eatNormalizeAgentRole(agentName)
	}
}

// extractTaskMetrics extracts metrics from Task tool results.
func (e *EmitAgentTrace) extractTaskMetrics(toolResult string) *traceMetrics {
	if toolResult == "" {
		return nil
	}
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(toolResult), &result); err != nil {
		return nil
	}
	metricsRaw, ok := result["metrics"].(map[string]interface{})
	if !ok {
		return nil
	}

	m := &traceMetrics{}
	hasValue := false

	if tc, ok := metricsRaw["tokenCount"].(float64); ok {
		v := int64(tc)
		m.TokenCount = &v
		hasValue = true
	}
	if tu, ok := metricsRaw["toolUses"].(float64); ok {
		v := int64(tu)
		m.ToolUses = &v
		hasValue = true
	}
	if d, ok := metricsRaw["duration"].(float64); ok {
		m.Duration = &d
		hasValue = true
	}

	if !hasValue {
		return nil
	}
	return m
}

// getVCSInfo returns Git information (cached).
func (e *EmitAgentTrace) getVCSInfo() *traceVCS {
	eatCache.mu.Lock()
	defer eatCache.mu.Unlock()

	if eatCache.vcsInfo != nil && time.Since(eatCache.vcsTime) < vcsCacheTTL {
		return eatCache.vcsInfo
	}

	vcs := eatFetchVCSInfo()
	eatCache.vcsInfo = vcs
	eatCache.vcsTime = time.Now()
	return vcs
}

// eatFetchVCSInfo obtains VCS information from git status.
func eatFetchVCSInfo() *traceVCS {
	out, err := eatRunGitCmd("status", "--porcelain=2", "-b", "-uno")
	if err != nil || out == "" {
		return nil
	}

	var revision, branch string
	dirty := false

	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, "# branch.oid ") {
			revision = strings.TrimPrefix(line, "# branch.oid ")
		} else if strings.HasPrefix(line, "# branch.head ") {
			branch = strings.TrimPrefix(line, "# branch.head ")
		} else if line != "" && !strings.HasPrefix(line, "#") {
			dirty = true
		}
	}

	if revision == "" || branch == "" {
		return nil
	}
	return &traceVCS{Revision: revision, Branch: branch, Dirty: dirty}
}

// getProjectMetadata returns project metadata (cached).
func (e *EmitAgentTrace) getProjectMetadata(repoRoot string) map[string]string {
	eatCache.mu.Lock()
	defer eatCache.mu.Unlock()

	if eatCache.projMeta != nil && time.Since(eatCache.projMetaTime) < traceCacheTTL {
		return eatCache.projMeta
	}

	meta := map[string]string{
		"project":     eatGetProjectName(repoRoot),
		"projectType": eatDetectProjectType(repoRoot),
	}
	eatCache.projMeta = meta
	eatCache.projMetaTime = time.Now()
	return meta
}

// getAttribution returns plugin attribution information (cached).
func (e *EmitAgentTrace) getAttribution() *traceAttribution {
	eatCache.mu.Lock()
	defer eatCache.mu.Unlock()

	if eatCache.attr != nil && time.Since(eatCache.attrTime) < traceCacheTTL {
		return eatCache.attr
	}

	attr := eatFetchAttribution()
	eatCache.attr = attr
	eatCache.attrTime = time.Now()
	return attr
}

// eatFetchAttribution reads plugin information from plugin.json.
func eatFetchAttribution() *traceAttribution {
	pluginRoot := os.Getenv("CLAUDE_PLUGIN_ROOT")
	if pluginRoot == "" {
		return nil
	}
	data, err := os.ReadFile(filepath.Join(pluginRoot, "plugin.json"))
	if err != nil {
		return nil
	}
	var pkg map[string]interface{}
	if err := json.Unmarshal(data, &pkg); err != nil {
		return nil
	}

	attr := &traceAttribution{
		Plugin:  getString(pkg, "name", "unknown"),
		Version: getString(pkg, "version", "unknown"),
	}
	if lic := getString(pkg, "license", ""); lic != "" {
		attr.License = lic
	}
	if author := getString(pkg, "author", ""); author != "" {
		attr.Author = author
	}
	return attr
}

// emitOtelSpan POSTs an OTel Span to the OTLP HTTP endpoint.
// The caller assumes a synchronous call. Since the HTTP client has a 3s timeout,
// it does not block for long. Failures are silently ignored.
func (e *EmitAgentTrace) emitOtelSpan(otlpEndpoint string, rec *traceRecord) {
	serviceVersion := eatReadServiceVersion()
	spanJSON := eatBuildOtelSpanJSON(rec, serviceVersion)

	data, err := json.Marshal(spanJSON)
	if err != nil {
		return
	}

	url := strings.TrimRight(otlpEndpoint, "/") + "/v1/traces"

	client := e.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 3 * time.Second}
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		_, _ = fmt.Fprintf(os.Stderr, "[agent-trace] otel export failed: %v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		_, _ = fmt.Fprintf(os.Stderr, "[agent-trace] otel export HTTP %d -> %s\n", resp.StatusCode, url)
	}
}

// eatBuildOtelSpanJSON builds the OTel Span JSON.
func eatBuildOtelSpanJSON(rec *traceRecord, serviceVersion string) map[string]interface{} {
	endMs := int64(0)
	if t, err := time.Parse(time.RFC3339, rec.Timestamp); err == nil {
		endMs = t.UnixMilli()
	}
	endNano := fmt.Sprintf("%d000000", endMs)

	// Derive trace ID and span ID from the UUID
	uuidHex := strings.ReplaceAll(rec.ID, "-", "")
	traceID := uuidHex
	spanID := uuidHex[:16]

	var attributes []map[string]interface{}

	if taskID, ok := rec.Metadata["taskId"].(string); ok && taskID != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "task.id",
			"value": map[string]string{"stringValue": taskID},
		})
	}
	if agentRole, ok := rec.Metadata["agentRole"].(string); ok && agentRole != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "agent.type",
			"value": map[string]string{"stringValue": agentRole},
		})
	}
	if effort, ok := rec.Metadata["effort"].(string); ok && effort != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "effort",
			"value": map[string]string{"stringValue": effort},
		})
	}
	attributes = append(attributes, map[string]interface{}{
		"key":   "tool.name",
		"value": map[string]string{"stringValue": rec.Tool},
	})
	if rec.VCS != nil && rec.VCS.Branch != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "vcs.branch",
			"value": map[string]string{"stringValue": rec.VCS.Branch},
		})
	}
	if sessionID, ok := rec.Metadata["sessionId"].(string); ok && sessionID != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "session.id",
			"value": map[string]string{"stringValue": sessionID},
		})
	}

	agentRole, _ := rec.Metadata["agentRole"].(string)
	spanName := "harness." + strings.ToLower(rec.Tool)
	if agentRole != "" {
		spanName = "harness." + agentRole
	}

	return map[string]interface{}{
		"resourceSpans": []map[string]interface{}{
			{
				"resource": map[string]interface{}{
					"attributes": []map[string]interface{}{
						{"key": "service.name", "value": map[string]string{"stringValue": "harness"}},
						{"key": "service.version", "value": map[string]string{"stringValue": serviceVersion}},
					},
				},
				"scopeSpans": []map[string]interface{}{
					{
						"scope": map[string]interface{}{"name": "harness.agent"},
						"spans": []map[string]interface{}{
							{
								"traceId":           traceID,
								"spanId":            spanID,
								"name":              spanName,
								"kind":              1,
								"startTimeUnixNano": endNano,
								"endTimeUnixNano":   endNano,
								"attributes":        attributes,
							},
						},
					},
				},
			},
		},
	}
}

// eatReadServiceVersion reads the version from plugin.json or VERSION.
func eatReadServiceVersion() string {
	pluginRoot := os.Getenv("CLAUDE_PLUGIN_ROOT")
	if pluginRoot == "" {
		return "0.0.0"
	}

	if data, err := os.ReadFile(filepath.Join(pluginRoot, "plugin.json")); err == nil {
		var pkg map[string]interface{}
		if err := json.Unmarshal(data, &pkg); err == nil {
			if v, ok := pkg["version"].(string); ok && v != "" {
				return v
			}
		}
	}

	if data, err := os.ReadFile(filepath.Join(pluginRoot, "VERSION")); err == nil {
		return strings.TrimSpace(string(data))
	}

	return "0.0.0"
}

// eatGetProjectName obtains the project name.
func eatGetProjectName(repoRoot string) string {
	pkgPath := filepath.Join(repoRoot, "package.json")
	if data, err := os.ReadFile(pkgPath); err == nil {
		var pkg map[string]interface{}
		if err := json.Unmarshal(data, &pkg); err == nil {
			if name, ok := pkg["name"].(string); ok && name != "" {
				return name
			}
		}
	}
	return filepath.Base(repoRoot)
}

// eatDetectProjectType detects the project type.
func eatDetectProjectType(repoRoot string) string {
	checks := [][2]string{
		{"next.config.js", "nextjs"},
		{"next.config.ts", "nextjs"},
		{"nuxt.config.js", "nuxt"},
		{"nuxt.config.ts", "nuxt"},
		{"svelte.config.js", "svelte"},
		{"astro.config.mjs", "astro"},
		{"Cargo.toml", "rust"},
		{"go.mod", "go"},
		{"pyproject.toml", "python"},
		{"setup.py", "python"},
		{"requirements.txt", "python"},
		{"Gemfile", "ruby"},
		{"composer.json", "php"},
		{"package.json", "node"},
	}
	for _, check := range checks {
		if _, err := os.Stat(filepath.Join(repoRoot, check[0])); err == nil {
			return check[1]
		}
	}
	return "unknown"
}

// eatNormalizeAgentRole normalizes an agent name to a harness role.
func eatNormalizeAgentRole(name string) string {
	v := strings.ToLower(strings.TrimSpace(name))
	if v == "" {
		return "unknown"
	}
	if strings.Contains(v, "review") {
		return "reviewer"
	}
	if strings.Contains(v, "lead") || strings.Contains(v, "planner") {
		return "lead"
	}
	if strings.Contains(v, "worker") || strings.Contains(v, "impl") {
		return "worker"
	}
	return v
}

// eatIsPathWithinRepo checks whether a path is within the repository.
func eatIsPathWithinRepo(filePath, repoRoot string) bool {
	if strings.Contains(filePath, "..") {
		return false
	}

	absPath := filePath
	if !filepath.IsAbs(filePath) {
		absPath = filepath.Join(repoRoot, filePath)
	}

	// Resolve the repository root to its real path
	resolvedRepo, err := filepath.EvalSymlinks(repoRoot)
	if err != nil {
		resolvedRepo = repoRoot
	}

	// If the file exists, check via its real path
	resolvedPath, err := filepath.EvalSymlinks(absPath)
	if err != nil {
		// If the file does not exist, check the parent directory
		parentDir := filepath.Dir(absPath)
		resolvedParent, err := filepath.EvalSymlinks(parentDir)
		if err != nil {
			resolvedPath = filepath.Clean(absPath)
		} else {
			resolvedPath = filepath.Join(resolvedParent, filepath.Base(absPath))
		}
	}

	return strings.HasPrefix(resolvedPath, resolvedRepo+string(filepath.Separator)) ||
		resolvedPath == resolvedRepo
}

// eatIsSupportedTool returns whether the tool is a trace target.
func eatIsSupportedTool(toolName string) bool {
	return toolName == "Edit" || toolName == "Write" || toolName == "MultiEdit" || toolName == "Task"
}

// eatGenerateUUID generates a UUID v4.
func eatGenerateUUID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		// Fallback: timestamp-based
		ts := time.Now().UnixNano()
		for i := 0; i < 8; i++ {
			b[i] = byte(ts >> (i * 8))
		}
	}
	// UUID v4 format
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%12x",
		b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

// getNow returns the current time as a string.
func (e *EmitAgentTrace) getNow() string {
	if e.Now != nil {
		return e.Now()
	}
	return time.Now().UTC().Format(time.RFC3339)
}

// getString obtains a string from a map. Returns the default value if not found.
func getString(m map[string]interface{}, key, defaultVal string) string {
	if v, ok := m[key].(string); ok && v != "" {
		return v
	}
	return defaultVal
}

// eatRunGitCmd runs a git command and returns its stdout.
func eatRunGitCmd(args ...string) (string, error) {
	out, err := gitport.Output("", args...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}
