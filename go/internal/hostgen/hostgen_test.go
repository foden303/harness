package hostgen

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const sampleHostsTOML = `
[claude]
hook_event = "PreToolUse"
hook_path  = ".claude-plugin/hooks.json"
matcher    = "Write|Edit|MultiEdit|Bash|Read"
deny       = "exit2"
transport  = "stdin-json"
model      = "opus"
`

func writeSampleHosts(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "hosts.toml")
	if err := os.WriteFile(path, []byte(sampleHostsTOML), 0o644); err != nil {
		t.Fatalf("write sample hosts.toml: %v", err)
	}
	return path
}

func TestLoad_ParsesClaude(t *testing.T) {
	hosts, err := Load(writeSampleHosts(t))
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(hosts) != 1 {
		t.Fatalf("expected 1 host, got %d (%v)", len(hosts), SortedNames(hosts))
	}

	claude, ok := hosts["claude"]
	if !ok {
		t.Fatal("missing claude host")
	}
	if claude.Name != "claude" {
		t.Errorf("claude.Name = %q, want %q", claude.Name, "claude")
	}
	if claude.HookEvent != "PreToolUse" {
		t.Errorf("claude.HookEvent = %q, want PreToolUse", claude.HookEvent)
	}
	if claude.HookPath != ".claude-plugin/hooks.json" {
		t.Errorf("claude.HookPath = %q", claude.HookPath)
	}
}

func TestLoad_MissingFile(t *testing.T) {
	if _, err := Load(filepath.Join(t.TempDir(), "nope.toml")); err == nil {
		t.Fatal("expected error for missing file, got nil")
	}
}

func TestLoad_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "empty.toml")
	if err := os.WriteFile(path, []byte("# only a comment\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(path); err == nil {
		t.Fatal("expected error for empty hosts.toml, got nil")
	}
}

func TestGenerateHooksJSON_Deterministic(t *testing.T) {
	hosts, err := Load(writeSampleHosts(t))
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range SortedNames(hosts) {
		h := hosts[name]
		a, err := GenerateHooksJSON(h)
		if err != nil {
			t.Fatalf("GenerateHooksJSON(%s) first call: %v", name, err)
		}
		b, err := GenerateHooksJSON(h)
		if err != nil {
			t.Fatalf("GenerateHooksJSON(%s) second call: %v", name, err)
		}
		if !bytes.Equal(a, b) {
			t.Errorf("GenerateHooksJSON(%s) not deterministic:\nfirst:\n%s\nsecond:\n%s", name, a, b)
		}
	}
}

func TestGenerateHooksJSON_ClaudeUsesValidRootWrapper(t *testing.T) {
	hosts, err := Load(writeSampleHosts(t))
	if err != nil {
		t.Fatal(err)
	}
	out, err := GenerateHooksJSON(hosts["claude"])
	if err != nil {
		t.Fatalf("GenerateHooksJSON(claude): %v", err)
	}
	s := string(out)
	if !strings.Contains(s, "valid_root") {
		t.Errorf("claude hooks.json should reuse the valid_root bootstrap wrapper:\n%s", s)
	}
	if !strings.Contains(s, "hook pre-tool") {
		t.Errorf("claude hooks.json should invoke 'hook pre-tool':\n%s", s)
	}
	var anyDoc map[string]interface{}
	if err := json.Unmarshal(out, &anyDoc); err != nil {
		t.Fatalf("claude hooks.json is not valid JSON: %v", err)
	}
}

func TestGenerateHooksJSON_UnknownHost(t *testing.T) {
	if _, err := GenerateHooksJSON(Host{Name: "antigravity", HookEvent: "preToolUse"}); err == nil {
		t.Fatal("expected error for unknown host, got nil")
	}
}

