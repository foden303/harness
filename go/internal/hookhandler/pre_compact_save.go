// Package hookhandler implements Go ports of the bash hook handler scripts.
package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/foden303/harness/go/internal/gitport"
	"github.com/foden303/harness/go/internal/plans"
)

// PreCompactSave is a Go port of pre-compact-save.js.
// On the PreCompact hook it generates handoff-artifact.json and precompact-snapshot.json.
//
// Original: scripts/hook-handlers/pre-compact-save.js
type PreCompactSave struct {
	// RepoRoot specifies the repository root.
	// If empty, it is auto-detected from cwd.
	RepoRoot string
	// StateDir specifies the location of snapshot files.
	// If empty, RepoRoot/.claude/state is used.
	StateDir string
	// PlansFile specifies the path to Plans.md.
	// If empty, RepoRoot/Plans.md is used.
	PlansFile string
	// Now returns the current time string (replaceable for testing).
	Now func() string
}

// artifactVersion is the version of the handoff artifact.
const artifactVersion = "2.0.0"

// legacySnapshotVersion is the version of the legacy snapshot.
const legacySnapshotVersion = "1.0.0"

// gitTimeoutSec is the timeout in seconds for git commands.
const gitTimeoutSec = 5

// planRow is the parse result of a single Plans.md line.
// It is an alias for the Task type of the canonical parser (internal/plans).
// Existing field access (.TaskID/.Title/.DoD/.Depends/.Status/.Tags) still works.
// plans.Tags adds a Done field, but the existing code in this file ignores it.
type planRow = plans.Task

// planTags is the tag info of a planRow.
// It is an alias for the Tags type of the canonical parser (internal/plans).
type planTags = plans.Tags

// openRisk is a risk entry.
type openRisk struct {
	Severity string `json:"severity"`
	Kind     string `json:"kind"`
	Summary  string `json:"summary"`
	Detail   string `json:"detail"`
}

// failedCheck is a failed-check entry.
type failedCheck struct {
	Source string `json:"source"`
	Check  string `json:"check"`
	Status string `json:"status"`
	Detail string `json:"detail,omitempty"`
}

// decisionLogEntry is a decision-log entry.
type decisionLogEntry struct {
	Timestamp string `json:"timestamp"`
	Actor     string `json:"actor"`
	Decision  string `json:"decision"`
	Rationale string `json:"rationale"`
}

// contextResetPolicy is the context reset policy.
type contextResetPolicy struct {
	Mode       string                 `json:"mode"`
	DryRun     bool                   `json:"dryRun"`
	Thresholds contextResetThresholds `json:"thresholds"`
}

// contextResetThresholds are the context reset thresholds.
type contextResetThresholds struct {
	WIPTasks          int `json:"wipTasks"`
	BlockedTasks      int `json:"blockedTasks"`
	RecentEdits       int `json:"recentEdits"`
	FailedChecks      int `json:"failedChecks"`
	SessionAgeMinutes int `json:"sessionAgeMinutes"`
}

// contextResetCandidate is a reset-decision candidate.
type contextResetCandidate struct {
	Key       string `json:"key"`
	Label     string `json:"label"`
	Actual    int    `json:"actual"`
	Threshold int    `json:"threshold"`
	Triggered bool   `json:"triggered"`
}

// contextResetCounters are the reset-decision counters.
type contextResetCounters struct {
	WIPTasks          int  `json:"wipTasks"`
	BlockedTasks      int  `json:"blockedTasks"`
	RecentEdits       int  `json:"recentEdits"`
	FailedChecks      int  `json:"failedChecks"`
	SessionAgeMinutes *int `json:"sessionAgeMinutes"`
}

// contextResetRecommendation is the context reset recommendation info.
type contextResetRecommendation struct {
	Policy      contextResetPolicy      `json:"policy"`
	Recommended bool                    `json:"recommended"`
	Summary     string                  `json:"summary"`
	Reasons     []string                `json:"reasons"`
	Candidates  []contextResetCandidate `json:"candidates"`
	Counters    contextResetCounters    `json:"counters"`
}

// continuityCTX is the continuity context.
type continuityCTX struct {
	PluginFirstWorkflow         bool   `json:"plugin_first_workflow"`
	ResumeAwareEffortContinuity bool   `json:"resume_aware_effort_continuity"`
	EffortHint                  string `json:"effort_hint"`
	ActiveSkill                 string `json:"active_skill,omitempty"`
	Summary                     string `json:"summary"`
}

// planCounts is the plan count info.
type planCounts struct {
	Total       int `json:"total"`
	WIP         int `json:"wip"`
	Blocked     int `json:"blocked"`
	RecentEdits int `json:"recent_edits"`
}

// sessionStateSnapshot is a session state snapshot.
type sessionStateSnapshot struct {
	State        string `json:"state,omitempty"`
	ResumedAt    string `json:"resumed_at,omitempty"`
	ActiveSkill  string `json:"active_skill,omitempty"`
	ReviewStatus string `json:"review_status,omitempty"`
}

// previousState is the previous state info.
type previousState struct {
	Summary      string                `json:"summary"`
	SessionState *sessionStateSnapshot `json:"session_state,omitempty"`
	PlanCounts   planCounts            `json:"plan_counts"`
}

// nextAction is the next-action info.
type nextAction struct {
	Summary  string `json:"summary"`
	TaskID   string `json:"taskId,omitempty"`
	Task     string `json:"task,omitempty"`
	DoD      string `json:"dod,omitempty"`
	Depends  string `json:"depends,omitempty"`
	Status   string `json:"status,omitempty"`
	Source   string `json:"source"`
	Priority string `json:"priority"`
}

// handoffArtifact is the entire handoff artifact.
type handoffArtifact struct {
	Version       string                     `json:"version"`
	LegacyVersion string                     `json:"legacy_version"`
	ArtifactType  string                     `json:"artifactType"`
	Timestamp     string                     `json:"timestamp"`
	SessionID     string                     `json:"sessionId"`
	PreviousState previousState              `json:"previous_state"`
	NextAction    nextAction                 `json:"next_action"`
	OpenRisks     []openRisk                 `json:"open_risks"`
	FailedChecks  []failedCheck              `json:"failed_checks"`
	DecisionLog   []decisionLogEntry         `json:"decision_log"`
	ContextReset  contextResetRecommendation `json:"context_reset"`
	Continuity    continuityCTX              `json:"continuity"`
	PlanItems     []planRow                  `json:"planItems"`
	WIPTasks      []string                   `json:"wipTasks"`
	RecentEdits   []string                   `json:"recentEdits"`
	Metrics       interface{}                `json:"metrics,omitempty"`
}

// preCompactResponse is the output of the PreCompact hook.
type preCompactResponse struct {
	Continue bool   `json:"continue"`
	Message  string `json:"message"`
}

// sessionStateFile is the (minimal) schema of the session state file.
type sessionStateFile struct {
	State       string `json:"state"`
	ResumedAt   string `json:"resumed_at"`
	ActiveSkill string `json:"active_skill"`
	StartedAt   string `json:"started_at"`
}

// workActiveFile is the (minimal) schema of work-active.json.
type workActiveFile map[string]interface{}

// sessionMetricsFile is the (minimal) schema of session-metrics.json.
type sessionMetricsFile map[string]interface{}

// Handle reads the PreCompact payload from stdin and generates
// handoff-artifact.json and precompact-snapshot.json.
func (h *PreCompactSave) Handle(r io.Reader, w io.Writer) error {
	now := h.getNow()
	sessionID := os.Getenv("CLAUDE_SESSION_ID")

	repoRoot := h.RepoRoot
	if repoRoot == "" {
		repoRoot = pcsFindRepoRoot()
	}

	stateDir := h.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(repoRoot, ".claude", "state")
	}

	plansFile := h.PlansFile
	if plansFile == "" {
		// resolvePlansPath resolves the path taking the plansDirectory setting into account,
		// and returns an empty string if the file does not exist (equivalent to the bash get_plans_file_path).
		plansFile = resolvePlansPath(repoRoot)
	}

	claudeDir := filepath.Join(repoRoot, ".claude")
	artifactPath := filepath.Join(stateDir, "handoff-artifact.json")
	snapshotPath := filepath.Join(stateDir, "precompact-snapshot.json")

	// Security: if .claude is a symlink, reject symlinks pointing outside the repo.
	// Symlinks inside the repo (e.g. a monorepo subpackage referencing a shared .claude) are allowed.
	if info, err := os.Lstat(claudeDir); err == nil && info.Mode()&os.ModeSymlink != 0 {
		target, resolveErr := filepath.EvalSymlinks(claudeDir)
		if resolveErr != nil {
			// If the symlink target cannot be resolved, reject it for safety.
			return writePreCompactJSON(w, preCompactResponse{
				Continue: true,
				Message:  "Skipped: security check failed (.claude symlink unresolvable)",
			})
		}
		// filepath.EvalSymlinks returns an OS path, so apply Clean before comparing.
		cleanTarget := filepath.Clean(target)
		cleanRoot := filepath.Clean(repoRoot)
		// HasPrefix would let /foo match /foobar, so check the prefix
		// with a trailing path separator.
		if cleanTarget != cleanRoot && !strings.HasPrefix(cleanTarget, cleanRoot+string(filepath.Separator)) {
			return writePreCompactJSON(w, preCompactResponse{
				Continue: true,
				Message:  "Skipped: security check failed (.claude symlink points outside repo)",
			})
		}
		// A symlink inside the repo is a legitimate usage, so continue.
	}

	// Create stateDir and run security check
	if err := h.ensureStateDir(stateDir); err != nil {
		return writePreCompactJSON(w, preCompactResponse{
			Continue: true,
			Message:  fmt.Sprintf("Skipped: %v", err),
		})
	}

	// Symlink check
	if isPreCompactSymlink(artifactPath) || isPreCompactSymlink(snapshotPath) {
		return writePreCompactJSON(w, preCompactResponse{
			Continue: true,
			Message:  "Skipped: artifact or snapshot is symlink",
		})
	}

	artifact := h.buildHandoffArtifact(repoRoot, plansFile, sessionID, now)

	// Write out
	if err := pcsWriteJSONFile(artifactPath, artifact); err != nil {
		return writePreCompactJSON(w, preCompactResponse{
			Continue: true,
			Message:  fmt.Sprintf("Error saving artifact: %v", err),
		})
	}

	// Legacy snapshot (kept for compatibility)
	snapshot := map[string]interface{}{
		"version":        legacySnapshotVersion,
		"legacy_version": artifact.LegacyVersion,
		"artifactType":   "precompact-snapshot",
		"timestamp":      artifact.Timestamp,
		"sessionId":      artifact.SessionID,
		"wipTasks":       artifact.WIPTasks,
		"recentEdits":    artifact.RecentEdits,
		"metrics":        artifact.Metrics,
		"context_reset":  artifact.ContextReset,
		"continuity":     artifact.Continuity,
	}
	if err := pcsWriteJSONFile(snapshotPath, snapshot); err != nil {
		// Snapshot failure is a warning only (the artifact is already saved)
		_ = err
	}

	return writePreCompactJSON(w, preCompactResponse{
		Continue: true,
		Message: fmt.Sprintf(
			"Saved structured handoff artifact: %d WIP tasks, %d recent edits",
			len(artifact.WIPTasks), len(artifact.RecentEdits),
		),
	})
}

// getNow returns the current time string.
func (h *PreCompactSave) getNow() string {
	if h.Now != nil {
		return h.Now()
	}
	return time.Now().UTC().Format(time.RFC3339)
}

// ensureStateDir creates the state directory.
func (h *PreCompactSave) ensureStateDir(stateDir string) error {
	if info, err := os.Lstat(stateDir); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("stateDir is a symlink")
		}
		_ = os.Chmod(stateDir, 0700)
		return nil
	}
	return os.MkdirAll(stateDir, 0700)
}

// buildHandoffArtifact builds the handoff artifact.
func (h *PreCompactSave) buildHandoffArtifact(repoRoot, plansFile, sessionID, now string) handoffArtifact {
	planRows := h.getPlanRows(plansFile)
	wipTasks := getWIPTasks(planRows)
	recentEdits := h.getRecentEdits(repoRoot)
	metrics := h.getSessionMetrics(repoRoot)
	workState := h.getWorkState(repoRoot)
	sessionState := h.getSessionStateFile(repoRoot)
	na := h.pickNextAction(planRows)
	openRisks := h.buildOpenRisks(planRows, recentEdits, workState, metrics)
	failedChecks := h.buildFailedChecks(workState, metrics)
	decisionLog := h.buildDecisionLog(now, na, workState)
	contextReset := h.buildContextResetRecommendation(planRows, recentEdits, workState, metrics, sessionState)
	continuity := h.buildContinuityContext(sessionState, na)

	wipCount := countWIP(planRows)
	blockedCount := countBlocked(planRows)

	var summaryParts []string
	if wipCount > 0 {
		summaryParts = append(summaryParts, fmt.Sprintf("%d WIP", wipCount))
	}
	if blockedCount > 0 {
		summaryParts = append(summaryParts, fmt.Sprintf("%d blocked", blockedCount))
	}
	if len(recentEdits) > 0 {
		summaryParts = append(summaryParts, fmt.Sprintf("%d recent edit(s)", len(recentEdits)))
	}

	prevSummary := "Before compaction: no active WIP tasks detected"
	if len(summaryParts) > 0 {
		prevSummary = "Before compaction: " + strings.Join(summaryParts, ", ")
	}

	var sessSnap *sessionStateSnapshot
	if sessionState != nil {
		var reviewStatus string
		if workState != nil {
			reviewStatus = getStringField(workState, "review_status", "reviewStatus")
		}
		sessSnap = &sessionStateSnapshot{
			State:        sessionState.State,
			ResumedAt:    sessionState.ResumedAt,
			ActiveSkill:  sessionState.ActiveSkill,
			ReviewStatus: reviewStatus,
		}
	}

	naItem := nextAction{
		Summary:  "Re-read Plans.md and determine the next task",
		Source:   "fallback",
		Priority: "normal",
	}
	if na != nil {
		naItem = *na
	}

	return handoffArtifact{
		Version:       artifactVersion,
		LegacyVersion: legacySnapshotVersion,
		ArtifactType:  "structured-handoff",
		Timestamp:     now,
		SessionID:     sessionID,
		PreviousState: previousState{
			Summary:      prevSummary,
			SessionState: sessSnap,
			PlanCounts: planCounts{
				Total:       len(planRows),
				WIP:         wipCount,
				Blocked:     blockedCount,
				RecentEdits: len(recentEdits),
			},
		},
		NextAction:   naItem,
		OpenRisks:    openRisks,
		FailedChecks: failedChecks,
		DecisionLog:  decisionLog,
		ContextReset: contextReset,
		Continuity:   continuity,
		PlanItems:    planRows,
		WIPTasks:     wipTasks,
		RecentEdits:  recentEdits,
		Metrics:      metrics,
	}
}

// getPlanRows reads and parses Plans.md and returns only active rows.
//
// The canonical parser (internal/plans) returns all task rows including completed ones,
// so here we filter to only rows matching cc:TODO / cc:WIP / cc:blocked
// (to preserve the behavior of pickNextAction / countWIP / countBlocked / getWIPTasks).
func (h *PreCompactSave) getPlanRows(plansFile string) []planRow {
	tasks, err := plans.ParseFile(plansFile)
	if err != nil {
		return nil
	}
	var rows []planRow
	for _, t := range tasks {
		if t.Tags.Todo || t.Tags.Wip || t.Tags.Blocked {
			rows = append(rows, t)
		}
	}
	return rows
}

// getWIPTasks returns the titles of the plan rows.
func getWIPTasks(rows []planRow) []string {
	var titles []string
	for _, row := range rows {
		if row.Title != "" {
			titles = append(titles, row.Title)
		}
	}
	return titles
}

// getRecentEdits gets recently changed files from git.
func (h *PreCompactSave) getRecentEdits(repoRoot string) []string {
	run := func(args ...string) string {
		out, err := gitport.Output(repoRoot, args...)
		if err != nil {
			return ""
		}
		return strings.TrimSpace(out)
	}

	staged := run("diff", "--name-only", "--cached")
	unstaged := run("diff", "--name-only")
	untracked := run("ls-files", "--others", "--exclude-standard")

	seen := map[string]bool{}
	var files []string
	for _, block := range []string{staged, unstaged, untracked} {
		if block == "" {
			continue
		}
		for _, f := range strings.Split(block, "\n") {
			if f == "" || seen[f] {
				continue
			}
			seen[f] = true
			files = append(files, f)
			if len(files) >= 20 {
				break
			}
		}
		if len(files) >= 20 {
			break
		}
	}
	return files
}

// getSessionMetrics loads the session metrics.
func (h *PreCompactSave) getSessionMetrics(repoRoot string) interface{} {
	p := filepath.Join(repoRoot, ".claude", "state", "session-metrics.json")
	return pcsReadJSONFile(p)
}

// getWorkState loads work-active.json.
func (h *PreCompactSave) getWorkState(repoRoot string) interface{} {
	stateDir := filepath.Join(repoRoot, ".claude", "state")
	for _, name := range []string{"work-active.json", "ultrawork-active.json"} {
		if v := pcsReadJSONFile(filepath.Join(stateDir, name)); v != nil {
			return v
		}
	}
	return nil
}

// getSessionStateFile loads the session state file.
func (h *PreCompactSave) getSessionStateFile(repoRoot string) *sessionStateFile {
	p := filepath.Join(repoRoot, ".claude", "state", "session.json")
	data, err := os.ReadFile(p)
	if err != nil {
		return nil
	}
	var s sessionStateFile
	if err := json.Unmarshal(data, &s); err != nil {
		return nil
	}
	return &s
}

// pickNextAction picks the highest-priority next action.
func (h *PreCompactSave) pickNextAction(rows []planRow) *nextAction {
	if len(rows) == 0 {
		return nil
	}
	// Priority order: WIP > TODO > blocked
	var preferred *planRow
	for i := range rows {
		if rows[i].Tags.Wip {
			preferred = &rows[i]
			break
		}
	}
	if preferred == nil {
		for i := range rows {
			if rows[i].Tags.Todo {
				preferred = &rows[i]
				break
			}
		}
	}
	if preferred == nil {
		preferred = &rows[0]
	}

	priority := "normal"
	if preferred.Tags.Blocked {
		priority = "blocked"
	} else if preferred.Tags.Wip {
		priority = "high"
	}

	summary := strings.TrimSpace("Continue " + preferred.TaskID + " " + preferred.Title)

	return &nextAction{
		TaskID:   preferred.TaskID,
		Task:     preferred.Title,
		DoD:      preferred.DoD,
		Depends:  preferred.Depends,
		Status:   preferred.Status,
		Source:   "Plans.md",
		Priority: priority,
		Summary:  summary,
	}
}

// buildOpenRisks builds the risk entries.
//
// Corresponds to buildOpenRisks in the JS pre-compact-save.js.
// It takes a metrics argument and converts failed validations in session-metrics.json into quality risks.
func (h *PreCompactSave) buildOpenRisks(rows []planRow, recentEdits []string, workState interface{}, metrics interface{}) []openRisk {
	var risks []openRisk

	wipCount := countWIP(rows)
	blockedCount := countBlocked(rows)

	if wipCount > 0 {
		var details []string
		for _, row := range rows {
			if row.Tags.Wip {
				details = append(details, row.TaskID+" "+row.Title)
			}
			if len(details) >= 5 {
				break
			}
		}
		risks = append(risks, openRisk{
			Severity: "medium",
			Kind:     "continuity",
			Summary:  fmt.Sprintf("%d WIP task(s) remain in Plans.md", wipCount),
			Detail:   strings.Join(details, "; "),
		})
	}

	if blockedCount > 0 {
		var details []string
		for _, row := range rows {
			if row.Tags.Blocked {
				details = append(details, row.TaskID+" "+row.Title)
			}
			if len(details) >= 5 {
				break
			}
		}
		risks = append(risks, openRisk{
			Severity: "high",
			Kind:     "dependency",
			Summary:  fmt.Sprintf("%d blocked task(s) need attention before finish", blockedCount),
			Detail:   strings.Join(details, "; "),
		})
	}

	if len(recentEdits) > 0 {
		detail := strings.Join(recentEdits, ", ")
		if len(recentEdits) > 5 {
			detail = strings.Join(recentEdits[:5], ", ")
		}
		risks = append(risks, openRisk{
			Severity: "medium",
			Kind:     "verification",
			Summary:  fmt.Sprintf("%d recent edit(s) should be re-validated after resume", len(recentEdits)),
			Detail:   detail,
		})
	}

	if workState != nil {
		reviewStatus := getStringField(workState, "review_status", "reviewStatus")
		if reviewStatus == "failed" {
			risks = append(risks, openRisk{
				Severity: "high",
				Kind:     "review",
				Summary:  "work review_status is failed",
				Detail:   getStringField(workState, "last_failure", "failure_reason", "reason"),
			})
		} else if reviewStatus != "" && reviewStatus != "passed" {
			// "passed" is no risk. Only unresolved states like "pending" are treated as medium risk
			risks = append(risks, openRisk{
				Severity: "medium",
				Kind:     "review",
				Summary:  fmt.Sprintf("work review_status is %s", reviewStatus),
				Detail:   "Independent review is still required before finalizing the work.",
			})
		}
	}

	// Convert failed validations in session-metrics.json into quality risks (symmetry with the JS version)
	if metrics != nil {
		failureCount := countFailures(metrics)
		if failureCount > 0 {
			risks = append(risks, openRisk{
				Severity: "high",
				Kind:     "quality",
				Summary:  fmt.Sprintf("%d recorded failed check(s) in session metrics", failureCount),
				Detail:   "Review the latest validation results before resuming work.",
			})
		}
	}

	if len(rows) > 0 && len(risks) == 0 {
		risks = append(risks, openRisk{
			Severity: "low",
			Kind:     "continuity",
			Summary:  "Open plan items still exist and should be re-read after compaction",
			Detail:   fmt.Sprintf("%d plan row(s) captured from Plans.md", len(rows)),
		})
	}

	if len(risks) > 8 {
		risks = risks[:8]
	}
	return risks
}

// buildFailedChecks builds the failed-check entries.
func (h *PreCompactSave) buildFailedChecks(workState, metrics interface{}) []failedCheck {
	var checks []failedCheck

	addFromSource := func(source string, value interface{}) {
		if value == nil {
			return
		}
		// If it is a single object (map), wrap it in an array for uniform handling (symmetry with the JS version)
		var items []interface{}
		switch v := value.(type) {
		case []interface{}:
			items = v
		case map[string]interface{}:
			items = []interface{}{v}
		default:
			return
		}
		for _, item := range items {
			switch entry := item.(type) {
			case string:
				checks = append(checks, failedCheck{Source: source, Check: entry, Status: "failed"})
			case map[string]interface{}:
				check := getStringField(entry, "check", "name", "type")
				if check == "" {
					check = "unknown"
				}
				checks = append(checks, failedCheck{
					Source: source,
					Check:  check,
					Status: getStringFieldDefault(entry, "failed", "status"),
					Detail: getStringField(entry, "detail", "message", "reason", "description"),
				})
			}
		}
	}

	if workState != nil {
		wsMap, ok := workState.(map[string]interface{})
		if ok {
			addFromSource("work-active.json", firstNonNil(
				wsMap["failed_checks"], wsMap["failedChecks"],
				wsMap["failures"], wsMap["checks_failed"],
			))
			reviewStatus := getStringField(wsMap, "review_status", "reviewStatus")
			if reviewStatus == "failed" && len(checks) == 0 {
				checks = append(checks, failedCheck{
					Source: "work-active.json",
					Check:  "review_status",
					Status: "failed",
					Detail: getStringField(wsMap, "last_failure", "failure_reason"),
				})
			}
		}
	}

	if metrics != nil {
		mMap, ok := metrics.(map[string]interface{})
		if ok {
			addFromSource("session-metrics.json", firstNonNil(
				mMap["failed_checks"], mMap["failedChecks"], mMap["failures"],
			))
		}
	}

	if len(checks) > 8 {
		checks = checks[:8]
	}
	return checks
}

// buildDecisionLog builds the decision log.
func (h *PreCompactSave) buildDecisionLog(now string, na *nextAction, workState interface{}) []decisionLogEntry {
	entries := []decisionLogEntry{
		{
			Timestamp: now,
			Actor:     "pre-compact-save",
			Decision:  "canonical_handoff_artifact_written",
			Rationale: "Persist a stable JSON artifact in .claude/state for long-running session handoff.",
		},
		{
			Timestamp: now,
			Actor:     "pre-compact-save",
			Decision:  "legacy_snapshot_mirrored",
			Rationale: "Keep precompact-snapshot.json for backward compatibility with older hooks.",
		},
	}

	if na != nil {
		entries = append(entries, decisionLogEntry{
			Timestamp: now,
			Actor:     "pre-compact-save",
			Decision:  "next_action_selected",
			Rationale: na.Summary + func() string {
				if na.Source != "" {
					return " (source: " + na.Source + ")"
				}
				return ""
			}(),
		})
	}

	if workState != nil {
		reviewStatus := getStringField(workState, "review_status", "reviewStatus")
		if reviewStatus != "" {
			entries = append(entries, decisionLogEntry{
				Timestamp: now,
				Actor:     "pre-compact-save",
				Decision:  "active_work_status_captured",
				Rationale: "work review_status=" + reviewStatus,
			})
		}
	}

	if len(entries) > 6 {
		entries = entries[:6]
	}
	return entries
}

// buildContextResetRecommendation builds the context reset recommendation.
func (h *PreCompactSave) buildContextResetRecommendation(
	rows []planRow, recentEdits []string,
	workState, metrics interface{},
	sessionState *sessionStateFile,
) contextResetRecommendation {
	policy := getContextResetPolicy()

	wipCount := countWIP(rows)
	blockedCount := countBlocked(rows)

	failureCount := 0
	if workState != nil {
		failureCount = countFailures(workState)
	}
	if metrics != nil && failureCount == 0 {
		failureCount = countFailures(metrics)
	}

	var sessionAgeMinutes *int
	if sessionState != nil && sessionState.StartedAt != "" {
		startedAt, err := time.Parse(time.RFC3339, sessionState.StartedAt)
		if err == nil {
			age := int(time.Since(startedAt).Minutes())
			if age < 0 {
				age = 0
			}
			sessionAgeMinutes = &age
		}
	}

	ageMinutes := 0
	if sessionAgeMinutes != nil {
		ageMinutes = *sessionAgeMinutes
	}

	type candidate struct {
		key, label        string
		actual, threshold int
	}
	candidates := []candidate{
		{"wip_tasks", "WIP task count", wipCount, policy.Thresholds.WIPTasks},
		{"blocked_tasks", "blocked task count", blockedCount, policy.Thresholds.BlockedTasks},
		{"recent_edits", "recent edit count", len(recentEdits), policy.Thresholds.RecentEdits},
		{"failed_checks", "failed check count", failureCount, policy.Thresholds.FailedChecks},
		{"session_age_minutes", "session age (minutes)", ageMinutes, policy.Thresholds.SessionAgeMinutes},
	}

	var reasons []string
	var candidateResults []contextResetCandidate
	for _, c := range candidates {
		triggered := c.actual >= c.threshold
		if triggered {
			reasons = append(reasons, fmt.Sprintf("%d %s exceed threshold %d", c.actual, c.label, c.threshold))
		}
		candidateResults = append(candidateResults, contextResetCandidate{
			Key:       c.key,
			Label:     c.label,
			Actual:    c.actual,
			Threshold: c.threshold,
			Triggered: triggered,
		})
	}

	recommended := len(reasons) > 0
	modeSuffix := policy.Mode
	if policy.DryRun {
		modeSuffix += ", dry-run"
	}

	var summary string
	if recommended {
		reasonStr := strings.Join(reasons, "; ")
		if len(reasons) > 4 {
			reasonStr = strings.Join(reasons[:4], "; ")
		}
		summary = fmt.Sprintf("Context reset recommended (%s): %s", modeSuffix, reasonStr)
	} else {
		summary = fmt.Sprintf("Context reset not required (%s)", modeSuffix)
	}

	return contextResetRecommendation{
		Policy:      policy,
		Recommended: recommended,
		Summary:     summary,
		Reasons:     reasons,
		Candidates:  candidateResults,
		Counters: contextResetCounters{
			WIPTasks:          wipCount,
			BlockedTasks:      blockedCount,
			RecentEdits:       len(recentEdits),
			FailedChecks:      failureCount,
			SessionAgeMinutes: sessionAgeMinutes,
		},
	}
}

// buildContinuityContext builds the continuity context.
func (h *PreCompactSave) buildContinuityContext(sessionState *sessionStateFile, na *nextAction) continuityCTX {
	effortHint := os.Getenv("HARNESS_EFFORT_DEFAULT")
	if effortHint == "" {
		effortHint = "medium"
	}

	var activeSkill string
	if sessionState != nil {
		activeSkill = sessionState.ActiveSkill
	}

	var summaryParts []string
	summaryParts = append(summaryParts, "plugin-first workflow: enabled")
	summaryParts = append(summaryParts, "resume-aware effort continuity: "+effortHint)
	if activeSkill != "" {
		summaryParts = append(summaryParts, "active_skill="+activeSkill)
	}
	if na != nil && na.TaskID != "" {
		summaryParts = append(summaryParts, "next_task="+na.TaskID)
	}

	return continuityCTX{
		PluginFirstWorkflow:         true,
		ResumeAwareEffortContinuity: true,
		EffortHint:                  effortHint,
		ActiveSkill:                 activeSkill,
		Summary:                     strings.Join(summaryParts, "; "),
	}
}

// getContextResetPolicy loads the policy from environment variables.
func getContextResetPolicy() contextResetPolicy {
	mode := os.Getenv("HARNESS_CONTEXT_RESET_MODE")
	if mode == "" {
		mode = "auto"
	}
	dryRunStr := os.Getenv("HARNESS_CONTEXT_RESET_DRY_RUN")
	dryRun := dryRunStr == "1" || strings.EqualFold(dryRunStr, "true") ||
		strings.EqualFold(dryRunStr, "yes") || strings.EqualFold(dryRunStr, "on")

	return contextResetPolicy{
		Mode:   mode,
		DryRun: dryRun,
		Thresholds: contextResetThresholds{
			WIPTasks:          parseEnvInt("HARNESS_CONTEXT_RESET_WIP_THRESHOLD", 4),
			BlockedTasks:      parseEnvInt("HARNESS_CONTEXT_RESET_BLOCKED_THRESHOLD", 1),
			RecentEdits:       parseEnvInt("HARNESS_CONTEXT_RESET_RECENT_EDITS_THRESHOLD", 8),
			FailedChecks:      parseEnvInt("HARNESS_CONTEXT_RESET_FAILED_CHECKS_THRESHOLD", 1),
			SessionAgeMinutes: parseEnvInt("HARNESS_CONTEXT_RESET_AGE_MINUTES", 120),
		},
	}
}

// parseEnvInt reads an environment variable as an int (returns the default value on failure).
func parseEnvInt(key string, defaultVal int) int {
	s := os.Getenv(key)
	if s == "" {
		return defaultVal
	}
	var n int
	_, err := fmt.Sscanf(s, "%d", &n)
	if err != nil || n <= 0 {
		return defaultVal
	}
	return n
}

// countWIP returns the number of WIP tasks.
func countWIP(rows []planRow) int {
	n := 0
	for _, r := range rows {
		if r.Tags.Wip {
			n++
		}
	}
	return n
}

// countBlocked returns the number of blocked tasks.
func countBlocked(rows []planRow) int {
	n := 0
	for _, r := range rows {
		if r.Tags.Blocked {
			n++
		}
	}
	return n
}

// countFailures gets the number of failures.
func countFailures(v interface{}) int {
	m, ok := v.(map[string]interface{})
	if !ok {
		return 0
	}
	for _, key := range []string{"failed_checks", "failedChecks", "failures"} {
		if val, ok := m[key]; ok {
			if arr, ok := val.([]interface{}); ok {
				return len(arr)
			}
		}
	}
	for _, key := range []string{"failure_count", "failed_count"} {
		if val, ok := m[key]; ok {
			switch n := val.(type) {
			case float64:
				return int(n)
			case int:
				return n
			}
		}
	}
	return 0
}

// getStringField returns the first string field found in the map.
func getStringField(v interface{}, keys ...string) string {
	m, ok := v.(map[string]interface{})
	if !ok {
		return ""
	}
	for _, k := range keys {
		if val, ok := m[k]; ok {
			if s, ok := val.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

// getStringFieldDefault returns a string field from the map. Returns the default value if not found.
func getStringFieldDefault(m map[string]interface{}, defaultVal string, keys ...string) string {
	for _, k := range keys {
		if val, ok := m[k]; ok {
			if s, ok := val.(string); ok && s != "" {
				return s
			}
		}
	}
	return defaultVal
}

// firstNonNil returns the first non-nil value.
func firstNonNil(vals ...interface{}) interface{} {
	for _, v := range vals {
		if v != nil {
			return v
		}
	}
	return nil
}

// pcsFindRepoRoot searches for .git from cwd and returns the repository root.
func pcsFindRepoRoot() string {
	dir, err := os.Getwd()
	if err != nil {
		return "."
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	cwd, _ := os.Getwd()
	return cwd
}

// pcsReadJSONFile reads a JSON file (returns nil on failure).
func pcsReadJSONFile(path string) interface{} {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var v interface{}
	if err := json.Unmarshal(data, &v); err != nil {
		return nil
	}
	return v
}

// pcsWriteJSONFile writes v out as a JSON file (perm 0600).
func pcsWriteJSONFile(path string, v interface{}) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0600)
}

// writePreCompactJSON writes the PreCompact JSON out to w.
func writePreCompactJSON(w io.Writer, resp preCompactResponse) error {
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}

// isPreCompactSymlink returns whether the path is a symlink.
func isPreCompactSymlink(path string) bool {
	info, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeSymlink != 0
}
