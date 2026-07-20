package hookhandler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/foden303/harness/go/internal/scaffold"
)

func TestMain(m *testing.M) {
	_ = os.Setenv("CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP", "0")
	os.Exit(m.Run())
}

// assertSetupOutput is a helper that validates the Setup hook response.
func assertSetupOutput(t *testing.T, output, wantSubstr string) {
	t.Helper()
	output = strings.TrimSpace(output)
	if output == "" {
		t.Fatal("expected JSON output, got empty")
	}

	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("output is not valid JSON: %v\noutput: %s", err, output)
	}

	hookOut, ok := resp["hookSpecificOutput"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing hookSpecificOutput in: %s", output)
	}
	if hookOut["hookEventName"] != "Setup" {
		t.Errorf("hookEventName = %q, want Setup", hookOut["hookEventName"])
	}
	ctx, _ := hookOut["additionalContext"].(string)
	if wantSubstr != "" && !strings.Contains(ctx, wantSubstr) {
		t.Errorf("additionalContext = %q, want to contain %q", ctx, wantSubstr)
	}
}

func TestHandleSetupHookInit_EmptyInput(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	var out bytes.Buffer
	err := HandleSetupHookInit(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// already initialized, or some message is returned
	output := strings.TrimSpace(out.String())
	if output == "" {
		t.Fatal("expected JSON output")
	}
	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("output is not valid JSON: %v\noutput: %s", err, output)
	}
	hookOut, ok := resp["hookSpecificOutput"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing hookSpecificOutput")
	}
	if hookOut["hookEventName"] != "Setup" {
		t.Errorf("hookEventName = %q, want Setup", hookOut["hookEventName"])
	}
}

func TestHandleSetupHookInit_CreatesHarnessToml(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	var out bytes.Buffer
	if err := HandleSetupHookInit(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(dir, "harness.toml"))
	if err != nil {
		t.Fatalf("harness.toml was not created: %v", err)
	}
	if string(data) != scaffold.HarnessTomlTemplate {
		t.Errorf("harness.toml content does not match scaffold.HarnessTomlTemplate")
	}
	assertSetupOutput(t, out.String(), "harness.toml created")
}

func TestHandleSetupHookInit_PreservesExistingHarnessToml(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	existing := "[project]\nname = \"user-edited\"\n"
	if err := os.WriteFile(filepath.Join(dir, "harness.toml"), []byte(existing), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	if err := HandleSetupHookInit(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(dir, "harness.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != existing {
		t.Errorf("existing harness.toml was overwritten:\ngot:  %q\nwant: %q", data, existing)
	}
	if strings.Contains(out.String(), "harness.toml created") {
		t.Errorf("output should not report harness.toml creation when it already exists: %s", out.String())
	}
}

func TestHandleSetupHookInit_CreatesStateDir(t *testing.T) {
	// set the temp directory as current
	dir := t.TempDir()
	origWD, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	var out bytes.Buffer
	if err := HandleSetupHookInit(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// check whether .claude/state/ was created
	stateDir := filepath.Join(dir, ".claude", "state")
	if info, err := os.Stat(stateDir); err != nil || !info.IsDir() {
		t.Errorf(".claude/state/ was not created at %s", stateDir)
	}
}

func TestHandleSetupHookInit_AlreadyInitialized(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	// create the state directory beforehand
	if err := os.MkdirAll(filepath.Join(dir, ".claude", "state"), 0o755); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	if err := HandleSetupHookInit(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertSetupOutput(t, out.String(), "[Setup:init]")
}

func TestHandleSetupHookInit_HarnessMemAutoSetupDisabledSilentSkip(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	fake, logPath := writeSetupFakeHarnessMem(t, "red")
	t.Setenv("HARNESS_MEM_CLI", fake)
	t.Setenv("CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP", "0")

	var out bytes.Buffer
	if err := HandleSetupHookInit(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, err := os.Stat(logPath); err == nil {
		t.Fatalf("auto setup should not call harness-mem when disabled")
	}
}

func TestHandleSetupHookInit_HarnessMemAutoSetupOnce(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	fake, logPath := writeSetupFakeHarnessMem(t, "red")
	t.Setenv("HARNESS_MEM_CLI", fake)
	t.Setenv("CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP", "1")

	var out bytes.Buffer
	if err := HandleSetupHookInit(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(out.String(), "harness-mem companion setup complete") {
		t.Fatalf("setup output should mention companion setup completion, got: %s", out.String())
	}

	out.Reset()
	if err := HandleSetupHookInit(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected second run error: %v", err)
	}

	logData, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.Count(string(logData), "setup --platform claude --skip-quality --auto-update enable"); got != 1 {
		t.Fatalf("setup should be attempted exactly once, got %d\nlog:\n%s", got, string(logData))
	}
}

func TestHandleSetupHookMaintenance_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleSetupHookMaintenance(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertSetupOutput(t, out.String(), "[Setup:maintenance]")
}

func TestHandleSetupHookMaintenance_CleansOldSessions(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	// create an old session file
	sessionsDir := filepath.Join(dir, ".claude", "state", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}

	oldFile := filepath.Join(sessionsDir, "session-old.json")
	if err := os.WriteFile(oldFile, []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}

	// set the file mtime to 8 days ago
	eightDaysAgo := time.Now().AddDate(0, 0, -8)
	if err := os.Chtimes(oldFile, eightDaysAgo, eightDaysAgo); err != nil {
		t.Fatal(err)
	}

	// also create a new session file (should not be deleted)
	newFile := filepath.Join(sessionsDir, "session-new.json")
	if err := os.WriteFile(newFile, []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	if err := HandleSetupHookMaintenance(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertSetupOutput(t, out.String(), "[Setup:maintenance]")

	// check whether the old file was deleted
	if _, err := os.Stat(oldFile); err == nil {
		t.Error("old session file should have been deleted")
	}
	// check whether the new file remains
	if _, err := os.Stat(newFile); err != nil {
		t.Error("new session file should still exist")
	}
}

func TestHandleSetupHookMaintenance_CleansTmpFiles(t *testing.T) {
	dir := t.TempDir()
	origWD, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	// create a .tmp file in the state directory
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	tmpFile := filepath.Join(stateDir, "test.tmp")
	if err := os.WriteFile(tmpFile, []byte("temp"), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	if err := HandleSetupHookMaintenance(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// check whether the .tmp file was deleted
	if _, err := os.Stat(tmpFile); err == nil {
		t.Error(".tmp file should have been deleted")
	}
}

func TestHandleSetupHook_UnknownMode(t *testing.T) {
	var out bytes.Buffer
	// send an unknown mode in the JSON payload
	payload := `{"mode":"unknown"}`
	if err := handleSetupHook(strings.NewReader(payload), &out, "unknown"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	output := strings.TrimSpace(out.String())
	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("output is not valid JSON: %v", err)
	}
	hookOut := resp["hookSpecificOutput"].(map[string]interface{})
	ctx := hookOut["additionalContext"].(string)
	if !strings.Contains(ctx, "unknown mode") {
		t.Errorf("expected unknown mode in %q", ctx)
	}
}

func TestIsSimpleMode(t *testing.T) {
	tests := []struct {
		envVal string
		want   bool
	}{
		{"1", true},
		{"true", true},
		{"TRUE", true},
		{"yes", true},
		{"YES", true},
		{"false", false},
		{"0", false},
		{"", false},
	}

	for _, tt := range tests {
		t.Run(tt.envVal, func(t *testing.T) {
			if tt.envVal != "" {
				t.Setenv("CLAUDE_CODE_SIMPLE", tt.envVal)
			} else {
				os.Unsetenv("CLAUDE_CODE_SIMPLE")
			}
			got := isSimpleMode()
			if got != tt.want {
				t.Errorf("isSimpleMode() = %v, want %v (env=%q)", got, tt.want, tt.envVal)
			}
		})
	}
}

func TestRemoveTmpFiles(t *testing.T) {
	dir := t.TempDir()

	// create a .tmp file
	tmpFile1 := filepath.Join(dir, "a.tmp")
	tmpFile2 := filepath.Join(dir, "subdir", "b.tmp")
	normalFile := filepath.Join(dir, "normal.json")

	_ = os.MkdirAll(filepath.Join(dir, "subdir"), 0o755)
	_ = os.WriteFile(tmpFile1, []byte("tmp1"), 0o644)
	_ = os.WriteFile(tmpFile2, []byte("tmp2"), 0o644)
	_ = os.WriteFile(normalFile, []byte("{}"), 0o644)

	removeTmpFiles(dir)

	if _, err := os.Stat(tmpFile1); err == nil {
		t.Error("a.tmp should have been deleted")
	}
	if _, err := os.Stat(tmpFile2); err == nil {
		t.Error("subdir/b.tmp should have been deleted")
	}
	if _, err := os.Stat(normalFile); err != nil {
		t.Error("normal.json should still exist")
	}
}

func TestCopyFile(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src.txt")
	dst := filepath.Join(dir, "dst.txt")

	content := []byte("hello world")
	if err := os.WriteFile(src, content, 0o644); err != nil {
		t.Fatal(err)
	}

	if err := copyFile(src, dst); err != nil {
		t.Fatalf("copyFile failed: %v", err)
	}

	got, err := os.ReadFile(dst)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(content) {
		t.Errorf("copied content = %q, want %q", got, content)
	}
}

// TestResolveSetupScriptDir_CLAUDE_PLUGIN_ROOT verifies CLAUDE_PLUGIN_ROOT takes precedence.
func TestResolveSetupScriptDir_CLAUDE_PLUGIN_ROOT(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("CLAUDE_PLUGIN_ROOT", dir)
	// also set HARNESS_SCRIPT_DIR to check precedence
	t.Setenv("HARNESS_SCRIPT_DIR", "/should/not/be/used")

	got := resolveSetupScriptDir()
	want := filepath.Join(dir, "scripts")
	if got != want {
		t.Errorf("resolveSetupScriptDir() = %q, want %q", got, want)
	}
}

// TestResolveSetupScriptDir_HARNESS_SCRIPT_DIR verifies that when CLAUDE_PLUGIN_ROOT is absent
// HARNESS_SCRIPT_DIR is used.
func TestResolveSetupScriptDir_HARNESS_SCRIPT_DIR(t *testing.T) {
	dir := t.TempDir()
	os.Unsetenv("CLAUDE_PLUGIN_ROOT")
	t.Setenv("HARNESS_SCRIPT_DIR", dir)

	got := resolveSetupScriptDir()
	if got != dir {
		t.Errorf("resolveSetupScriptDir() = %q, want %q", got, dir)
	}
}

// TestResolveSetupScriptDir_CWDFallback verifies CWD/scripts is returned when both env vars are absent.
func TestResolveSetupScriptDir_CWDFallback(t *testing.T) {
	dir := t.TempDir()
	origWD, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD) //nolint:errcheck

	os.Unsetenv("CLAUDE_PLUGIN_ROOT")
	os.Unsetenv("HARNESS_SCRIPT_DIR")

	got := resolveSetupScriptDir()

	// on macOS os.Getwd() returns the real path via /private/var, but
	// t.TempDir() can return a path via /var (symlink).
	// handle this by checking that the path ends with "/scripts".
	if filepath.Base(got) != "scripts" {
		t.Errorf("resolveSetupScriptDir() = %q, want path ending in 'scripts'", got)
	}
	// the return value is os.Getwd() + "/scripts", so the directory part matches CWD
	// (comparison after symlink resolution)
	cwd, _ := os.Getwd()
	gotDir := filepath.Dir(got)
	gotDirReal, _ := filepath.EvalSymlinks(gotDir)
	cwdReal, _ := filepath.EvalSymlinks(cwd)
	if gotDirReal != cwdReal {
		t.Errorf("resolveSetupScriptDir() parent = %q (real: %q), want CWD = %q (real: %q)",
			gotDir, gotDirReal, cwd, cwdReal)
	}
}

func TestNewYAMLValidationCommand_PassesConfigAsArg(t *testing.T) {
	configFile := `bad"path;import os;os.system("touch pwned")#.yaml`

	cmd := newYAMLValidationCommand(configFile)

	if cmd.Path != "python3" && filepath.Base(cmd.Path) != "python3" {
		t.Fatalf("cmd.Path = %q, want python3", cmd.Path)
	}
	if len(cmd.Args) != 4 {
		t.Fatalf("cmd.Args = %#v, want 4 args", cmd.Args)
	}
	if cmd.Args[1] != "-c" {
		t.Fatalf("cmd.Args[1] = %q, want -c", cmd.Args[1])
	}
	if strings.Contains(cmd.Args[2], configFile) {
		t.Fatalf("python script must not interpolate config path: %q", cmd.Args[2])
	}
	if cmd.Args[3] != configFile {
		t.Fatalf("config arg = %q, want %q", cmd.Args[3], configFile)
	}
}

// the time package is also used in setup_hook_test.go
var _ = time.Now

func writeSetupFakeHarnessMem(t *testing.T, mode string) (string, string) {
	t.Helper()
	dir := t.TempDir()
	logPath := filepath.Join(dir, "calls.log")
	scriptPath := filepath.Join(dir, "harness-mem")
	script := fmt.Sprintf(`#!/bin/sh
set -eu
printf '%%s\n' "$*" >> %q
cmd="${1:-}"
shift || true
case "$cmd" in
  doctor)
    case %q in
      healthy)
        printf '%%s\n' '{"status":"healthy","all_green":true,"failed_count":0,"checked_count":1,"timestamp":"2026-05-05T00:00:00Z","checks":[],"fix_command":"harness-mem doctor --fix","backend_mode":"local","contract_version":"claude-harness-companion.v1","harness_mem_version":"0.0.0-test"}'
        ;;
      red)
        printf '%%s\n' '{"status":"unhealthy","all_green":false,"failed_count":1,"checked_count":1,"timestamp":"2026-05-05T00:00:00Z","checks":[{"name":"codex_wiring","status":"missing","fix":"harness-mem setup --platform codex"}],"fix_command":"harness-mem doctor --fix","backend_mode":"local","contract_version":"claude-harness-companion.v1","harness_mem_version":"0.0.0-test"}'
        ;;
    esac
    ;;
  setup)
    printf 'setup-ok\n'
    ;;
  *)
    printf 'unknown command: %%s\n' "$cmd" >&2
    exit 2
    ;;
esac
`, logPath, mode)
	if err := os.WriteFile(scriptPath, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return scriptPath, logPath
}
