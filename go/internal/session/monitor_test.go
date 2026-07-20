package session

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestMonitorHandler_GeneratesSessionFile(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	plansFile := filepath.Join(dir, "Plans.md")

	// create Plans.md
	plans := "| t1 | cc:WIP |\n| t2 | cc:TODO |\n"
	if err := os.WriteFile(plansFile, []byte(plans), 0644); err != nil {
		t.Fatal(err)
	}

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: plansFile,
		now:       func() time.Time { return time.Date(2026, 4, 5, 12, 0, 0, 0, time.UTC) },
	}

	inp := `{"cwd":"` + dir + `"}`
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(inp), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// check that session.json was created
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}

	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}

	if sess.State != "initialized" {
		t.Errorf("expected state=initialized, got %q", sess.State)
	}
	if sess.SessionID == "" {
		t.Errorf("expected non-empty session_id")
	}
	if sess.Plans.WIPTasks != 1 {
		t.Errorf("expected wip_tasks=1, got %d", sess.Plans.WIPTasks)
	}
	if sess.Plans.TODOTasks != 1 {
		t.Errorf("expected todo_tasks=1, got %d", sess.Plans.TODOTasks)
	}
}

func TestMonitorHandler_GeneratesToolingPolicy(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	policyFile := filepath.Join(stateDir, "tooling-policy.json")
	data, err := os.ReadFile(policyFile)
	if err != nil {
		t.Fatalf("tooling-policy.json not created: %v", err)
	}

	var policy toolingPolicyJSON
	if err := json.Unmarshal(data, &policy); err != nil {
		t.Fatalf("invalid tooling-policy.json: %v\nraw: %s", err, data)
	}

	if policy.LSP.Available {
		t.Errorf("expected lsp.available=false")
	}
	if policy.Skills.DecisionRequired {
		t.Errorf("expected skills.decision_required=false")
	}
}

func TestMonitorHandler_ResumesExistingSession(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// create an existing session
	existingSession := sessionStateJSON{
		SessionID:          "session-existing",
		State:              "running",
		StateVersion:       1,
		StartedAt:          "2026-04-05T10:00:00Z",
		UpdatedAt:          "2026-04-05T10:00:00Z",
		ResumeToken:        "resume-token",
		EventSeq:           5,
		Plans:              plansStateJSON{Exists: false},
		Git:                gitStateJSON{Branch: "main"},
		ChangesThisSession: []interface{}{},
	}
	existingData, _ := json.MarshalIndent(existingSession, "", "  ")
	sessionFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(sessionFile, existingData, 0600); err != nil {
		t.Fatal(err)
	}

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// the session_id of a resumed session does not change
	data, _ := os.ReadFile(sessionFile)
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatal(err)
	}

	if sess.SessionID != "session-existing" {
		t.Errorf("expected session_id=session-existing (resume), got %q", sess.SessionID)
	}
	if sess.ResumeToken != "resume-token" {
		t.Errorf("expected resume_token preserved, got %q", sess.ResumeToken)
	}
}

func TestMonitorHandler_NewSessionOnStopped(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// create a stopped session
	existingSession := map[string]interface{}{
		"session_id": "session-old",
		"state":      "stopped",
		"started_at": "2026-04-04T10:00:00Z",
	}
	existingData, _ := json.MarshalIndent(existingSession, "", "  ")
	sessionFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(sessionFile, existingData, 0600); err != nil {
		t.Fatal(err)
	}

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, _ := os.ReadFile(sessionFile)
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatal(err)
	}

	// a new session_id should have been generated
	if sess.SessionID == "session-old" {
		t.Errorf("expected new session_id, got session-old")
	}
	if sess.State != "initialized" {
		t.Errorf("expected state=initialized, got %q", sess.State)
	}
}

func TestMonitorHandler_SymlinkStateDir(t *testing.T) {
	dir := t.TempDir()
	realDir := filepath.Join(dir, "real-state")
	if err := os.MkdirAll(realDir, 0700); err != nil {
		t.Fatal(err)
	}
	linkDir := filepath.Join(dir, "link-state")
	if err := os.Symlink(realDir, linkDir); err != nil {
		t.Skip("symlink creation not supported")
	}

	h := &MonitorHandler{StateDir: linkDir}
	var out bytes.Buffer
	// should not error (early return)
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestMonitorHandler_ReadGitBranch(t *testing.T) {
	dir := t.TempDir()
	runGitCmd(t, dir, "init", "-q")
	runGitCmd(t, dir, "config", "user.name", "Test User")
	runGitCmd(t, dir, "config", "user.email", "test@example.com")
	if err := os.WriteFile(filepath.Join(dir, "README.md"), []byte("hello\n"), 0644); err != nil {
		t.Fatal(err)
	}
	runGitCmd(t, dir, "add", "README.md")
	runGitCmd(t, dir, "commit", "-qm", "init")
	runGitCmd(t, dir, "checkout", "-qb", "feat/test")

	h := &MonitorHandler{}
	branch := h.readGitBranch(dir)
	if branch != "feat/test" {
		t.Errorf("expected branch=feat/test, got %q", branch)
	}
}

func TestMonitorHandler_CollectGitState_Worktree(t *testing.T) {
	repoDir := t.TempDir()
	runGitCmd(t, repoDir, "init", "-q")
	runGitCmd(t, repoDir, "config", "user.name", "Test User")
	runGitCmd(t, repoDir, "config", "user.email", "test@example.com")
	if err := os.WriteFile(filepath.Join(repoDir, "README.md"), []byte("hello\n"), 0644); err != nil {
		t.Fatal(err)
	}
	runGitCmd(t, repoDir, "add", "README.md")
	runGitCmd(t, repoDir, "commit", "-qm", "init")

	worktreeDir := filepath.Join(t.TempDir(), "feature-worktree")
	runGitCmd(t, repoDir, "worktree", "add", "-b", "feature/worktree", worktreeDir, "HEAD")

	h := &MonitorHandler{}
	gitState := h.collectGitState(worktreeDir)
	if gitState.Branch != "feature/worktree" {
		t.Fatalf("expected branch=feature/worktree, got %q", gitState.Branch)
	}
	if gitState.LastCommit == "none" || gitState.LastCommit == "unknown" || gitState.LastCommit == "" {
		t.Fatalf("expected last_commit from worktree, got %q", gitState.LastCommit)
	}
}

func runGitCmd(t *testing.T, dir string, args ...string) string {
	t.Helper()

	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s failed: %v\n%s", strings.Join(args, " "), err, output)
	}
	return strings.TrimSpace(string(output))
}

func TestMonitorHandler_WriteSummary(t *testing.T) {
	h := &MonitorHandler{}
	var out bytes.Buffer
	h.writeSummary(&out, "my-project", gitStateJSON{Branch: "main"}, plansStateJSON{
		Exists:    true,
		WIPTasks:  2,
		TODOTasks: 3,
	})

	s := out.String()
	if !strings.Contains(s, "my-project") {
		t.Errorf("expected project name in summary, got:\n%s", s)
	}
	if !strings.Contains(s, "main") {
		t.Errorf("expected branch in summary, got:\n%s", s)
	}
	if !strings.Contains(s, "WIP 2") {
		t.Errorf("expected WIP count in summary, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.1.1: harness-mem health detection tests
// ---------------------------------------------------------------------------

func TestMonitorHandler_HarnessMemHealthy(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return true, "", nil
		},
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// no warning when healthy
	s := out.String()
	if strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("expected no unhealthy warning for healthy state, got:\n%s", s)
	}

	// the harness_mem field is written in session.json
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}
	if !sess.HarnessMem.Healthy {
		t.Errorf("expected harness_mem.healthy=true in session.json")
	}
}

func TestMonitorHandler_HarnessMemUnhealthy(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return false, "daemon-unreachable", nil
		},
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("expected unhealthy warning in output, got:\n%s", s)
	}
	if !strings.Contains(s, "daemon-unreachable") {
		t.Errorf("expected reason 'daemon-unreachable' in warning, got:\n%s", s)
	}

	// harness_mem.healthy in session.json is false
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}
	if sess.HarnessMem.Healthy {
		t.Errorf("expected harness_mem.healthy=false in session.json")
	}
	if sess.HarnessMem.LastError != "daemon-unreachable" {
		t.Errorf("expected harness_mem.last_error=daemon-unreachable, got %q", sess.HarnessMem.LastError)
	}
}

// TestMonitorHandler_HarnessMemNotConfigured pins that the `⚠️ harness-mem unhealthy`
// warning does not misfire in the session of a user who has not installed harness-mem.
// The mem health check introduced in v4.3.1 returned `not-initialized`/unhealthy when
// `~/.claude-mem/` was absent, emitting a warning even to users outside the monitoring
// scope; this regression was fixed in v4.3.3 (opt-in unused = treated as healthy=true + reason="not-configured").
func TestMonitorHandler_HarnessMemNotConfigured(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return true, "not-configured", nil
		},
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("not-configured must NOT emit unhealthy warning, got:\n%s", s)
	}

	// harness_mem.healthy=true in session.json, LastError empty (because healthy)
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}
	if !sess.HarnessMem.Healthy {
		t.Errorf("expected harness_mem.healthy=true (monitor exclusion), got false")
	}
	if sess.HarnessMem.LastError != "" {
		t.Errorf("expected harness_mem.last_error=\"\" when healthy, got %q", sess.HarnessMem.LastError)
	}
}

func TestMonitorHandler_HarnessMemTimeout(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return false, "timeout", fmt.Errorf("context deadline exceeded")
		},
	}

	var out bytes.Buffer
	// the handler as a whole does not stop even on timeout/error
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("expected unhealthy warning for timeout, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.1.2: advisor/reviewer drift detection tests
// ---------------------------------------------------------------------------

func TestMonitorHandler_AdvisorDrift_Hit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// write an advisor-request more than 600 seconds ago (exceeds TTL=600)
	oldTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"advisor-request.v1","task_id":"t1","trigger_hash":"abc123","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "advisor drift") {
		t.Errorf("expected advisor drift warning, got:\n%s", s)
	}
	if !strings.Contains(s, "waiting") {
		t.Errorf("expected 'waiting' in advisor drift output, got:\n%s", s)
	}
}

func TestMonitorHandler_AdvisorDrift_Miss(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// advisor-request under TTL (50 seconds ago)
	recentTime := time.Now().Add(-50 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"advisor-request.v1","task_id":"t2","trigger_hash":"xyz789","ts":"%s"}`, recentTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if strings.Contains(s, "advisor drift") {
		t.Errorf("expected no advisor drift warning for TTL-miss, got:\n%s", s)
	}
}

func TestMonitorHandler_AdvisorDrift_ConfigOverride(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// set advisor_ttl_seconds=10 in config.yaml
	configContent := `orchestration:
  advisor_ttl_seconds: 10
`
	if err := os.WriteFile(filepath.Join(dir, ".harness.config.yaml"), []byte(configContent), 0644); err != nil {
		t.Fatal(err)
	}

	// advisor-request 15 seconds ago (exceeds TTL=10)
	oldTime := time.Now().Add(-15 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"advisor-request.v1","task_id":"t3","trigger_hash":"cfg001","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "advisor drift") {
		t.Errorf("expected advisor drift warning with config override TTL=10, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.2.1: reviewer drift tests (Phase 48.2 follow-up)
// reviewer drift shares the same TTL as advisor drift (orchestration.advisor_ttl_seconds).
// The schemas it detects are review-request.v1 / review-result.v1.
// ---------------------------------------------------------------------------

func TestMonitorHandler_ReviewerDrift_Hit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// review-request 700 seconds ago (exceeds TTL=600)
	oldTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"review-request.v1","task_id":"rev1","trigger_hash":"rev0001","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "reviewer drift") {
		t.Errorf("expected reviewer drift warning, got:\n%s", s)
	}
	if !strings.Contains(s, "waiting") {
		t.Errorf("expected 'waiting' in reviewer drift output, got:\n%s", s)
	}
}

func TestMonitorHandler_ReviewerDrift_Miss(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// request is past TTL but review-result.v1 has already arrived → not drift
	baseTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	reqLine := fmt.Sprintf(`{"schema_version":"review-request.v1","task_id":"rev2","trigger_hash":"rev0002","ts":"%s"}`, baseTime)
	resLine := fmt.Sprintf(`{"schema_version":"review-result.v1","task_id":"rev2","trigger_hash":"rev0002","ts":"%s"}`, baseTime)
	if err := os.WriteFile(eventsFile, []byte(reqLine+"\n"+resLine+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if strings.Contains(s, "reviewer drift") {
		t.Errorf("expected no reviewer drift warning when response exists, got:\n%s", s)
	}
}

func TestMonitorHandler_ReviewerDrift_ConfigOverride(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// set advisor_ttl_seconds=10 in config.yaml (reviewer drift shares the same TTL)
	configContent := `orchestration:
  advisor_ttl_seconds: 10
`
	if err := os.WriteFile(filepath.Join(dir, ".harness.config.yaml"), []byte(configContent), 0644); err != nil {
		t.Fatal(err)
	}

	// review-request 15 seconds ago (exceeds TTL=10)
	oldTime := time.Now().Add(-15 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"review-request.v1","task_id":"rev3","trigger_hash":"rev0003","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "reviewer drift") {
		t.Errorf("expected reviewer drift warning with config override TTL=10, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.1.3: Plans.md threshold evaluation tests
// ---------------------------------------------------------------------------

func TestMonitorHandler_PlansDrift_WIPThresholdHit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// WIPTasks=5 (default threshold)
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     5,
		LastModified: now.Add(-1 * time.Hour).Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result == "" {
		t.Errorf("expected plans drift warning for WIP=5, got empty")
	}
	if !strings.Contains(result, "plans drift") {
		t.Errorf("expected 'plans drift' in output, got: %s", result)
	}
}

func TestMonitorHandler_PlansDrift_StaleHit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// updated 25 hours ago (exceeds stale_hours=24)
	staleTime := now.Add(-25 * time.Hour)
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     1,
		LastModified: staleTime.Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result == "" {
		t.Errorf("expected plans drift warning for stale Plans.md, got empty")
	}
	if !strings.Contains(result, "plans drift") {
		t.Errorf("expected 'plans drift' in output, got: %s", result)
	}
	if !strings.Contains(result, "stale_for=25h") {
		t.Errorf("expected stale_for=25h in output, got: %s", result)
	}
}

func TestMonitorHandler_PlansDrift_BelowThreshold(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// WIP=2 (below threshold 5), updated 1 hour ago (below stale_hours=24)
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     2,
		LastModified: now.Add(-1 * time.Hour).Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result != "" {
		t.Errorf("expected no plans drift warning below threshold, got: %s", result)
	}
}

func TestMonitorHandler_PlansDrift_ConfigOverride(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	// set wip_threshold=3 in config.yaml
	configContent := `monitor:
  plans_drift:
    wip_threshold: 3
    stale_hours: 48
`
	if err := os.WriteFile(filepath.Join(dir, ".harness.config.yaml"), []byte(configContent), 0644); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// WIP=3 (meets config threshold=3)
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     3,
		LastModified: now.Add(-1 * time.Hour).Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result == "" {
		t.Errorf("expected plans drift warning for WIP=3 with config threshold=3, got empty")
	}
}

// ---------------------------------------------------------------------------
// Issue #94 Item 3: collectDrift bounded memory (container/ring) contract test
// ---------------------------------------------------------------------------

// TestCollectDrift_TailWindowBoundary is a regression test pinning the boundary
// that only the trailing driftTailWindow (=200) lines are subject to drift detection.
//
// Among a 500-line events.jsonl, it verifies that only the advisor-request inside the
// trailing 200 lines is detected, and the advisor-request outside (toward the front) is ignored.
// This guarantees the boundary is maintained after switching to a ring buffer.
func TestCollectDrift_TailWindowBoundary(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")

	oldTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	var buf bytes.Buffer

	// line 1..299: irrelevant events (outside the trailing 200 lines)
	for i := 0; i < 299; i++ {
		fmt.Fprintf(&buf, `{"schema_version":"other","task_id":"noise%d","trigger_hash":"nh%d","ts":"%s"}`+"\n", i, i, oldTime)
	}
	// line 300: outside advisor-request → outside the window, expected not to be detected
	fmt.Fprintf(&buf, `{"schema_version":"advisor-request.v1","task_id":"t_outside","trigger_hash":"outside","ts":"%s"}`+"\n", oldTime)
	// line 301..499: irrelevant events (trailing 200 lines = line 301..500)
	for i := 0; i < 199; i++ {
		fmt.Fprintf(&buf, `{"schema_version":"other","task_id":"tail%d","trigger_hash":"th%d","ts":"%s"}`+"\n", i, i, oldTime)
	}
	// line 500: inside advisor-request → inside the window, expected to be detected
	fmt.Fprintf(&buf, `{"schema_version":"advisor-request.v1","task_id":"t_inside","trigger_hash":"inside","ts":"%s"}`+"\n", oldTime)

	if err := os.WriteFile(eventsFile, buf.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	warnings := h.collectDrift(stateDir, dir)
	joined := strings.Join(warnings, " | ")

	if !strings.Contains(joined, "t_inside") {
		t.Errorf("expected t_inside advisor drift warning (inside tail %d), got:\n%s", driftTailWindow, joined)
	}
	if strings.Contains(joined, "t_outside") {
		t.Errorf("expected NO t_outside advisor drift warning (outside tail %d), got:\n%s", driftTailWindow, joined)
	}
}

// benchCollectDrift is a helper for measuring the memory/time cost of collectDrift
// while varying the number of lines in session.events.jsonl.
//
// To satisfy Issue #94 Item 3's Exit criteria "benchmark showing bounded growth with N lines",
// running `go test -bench=BenchmarkCollectDrift -benchmem` with N=200 and N=10000 side by side
// lets you manually confirm that, thanks to the ring buffer, the **later-stage retention**
// (`lines` slice expansion) is not proportional to N but bounded to driftTailWindow (=200).
// (The short-lived string allocations from scanner.Text() are proportional to N in both
//
//	implementations, but peak in-use memory is fixed by the ring.)
func benchCollectDrift(b *testing.B, numLines int) {
	dir := b.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		b.Fatal(err)
	}
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")

	f, err := os.Create(eventsFile)
	if err != nil {
		b.Fatal(err)
	}
	padding := strings.Repeat("x", 150)
	for i := 0; i < numLines; i++ {
		fmt.Fprintf(f, `{"schema_version":"other","task_id":"t%d","trigger_hash":"h%d","ts":"2026-01-01T00:00:00Z","padding":"%s"}`+"\n", i, i, padding)
	}
	if err := f.Close(); err != nil {
		b.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = h.collectDrift(stateDir, dir)
	}
}

// BenchmarkCollectDrift_200Lines is the baseline for input exactly at the trailing window size (=200).
func BenchmarkCollectDrift_200Lines(b *testing.B) {
	benchCollectDrift(b, 200)
}

// BenchmarkCollectDrift_10000Lines is input 50x the window.
// After switching to a ring buffer, the finally allocated lines slice is always bounded to 200
// elements, showing that the "final retained allocation" stays the same order as the 200-line bench.
func BenchmarkCollectDrift_10000Lines(b *testing.B) {
	benchCollectDrift(b, 10000)
}

// TestMonitorHandler_RegisterNotConfigured is the Phase 81.1.3 regression
// test for the active-watching-test-policy tri-state contract: the
// session-register state lives at .claude/sessions/active.json, but
// session-monitor must not warn when that file is missing. Coordination
// is opt-in; absence == silence. This pins the invariant so a future
// monitor refactor that starts reading active.json still cannot emit
// a "register not-configured" warning into the SessionStart output.
func TestMonitorHandler_RegisterNotConfigured(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	// No active.json, no .claude/sessions directory — the "register not
	// configured" arm of the tri-state.

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return true, "", nil
		},
		now: func() time.Time { return time.Date(2026, 5, 29, 12, 0, 0, 0, time.UTC) },
	}

	in := strings.NewReader(`{"session_id":"sess-monitor","cwd":"` + dir + `"}`)
	var out bytes.Buffer
	if err := h.Handle(in, &out); err != nil {
		t.Fatalf("monitor handler should not fail when register is absent: %v", err)
	}

	got := out.String()
	for _, forbidden := range []string{
		"register",
		"active.json",
		"⚠️ register",
		"not-configured",
	} {
		if strings.Contains(got, forbidden) {
			t.Errorf("monitor output must not warn about absent register; saw %q in: %s", forbidden, got)
		}
	}
}
