package hookhandler

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestResolvePlansPath_Default verifies the default path is returned with no config and an existing Plans.md.
func TestResolvePlansPath_Default(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	got := resolvePlansPath(dir)
	if got != plansPath {
		t.Errorf("resolvePlansPath() = %q, want %q", got, plansPath)
	}
}

// TestResolvePlansPath_FileNotExist verifies an empty string is returned when Plans.md does not exist.
func TestResolvePlansPath_FileNotExist(t *testing.T) {
	dir := t.TempDir()
	// Do not create Plans.md

	got := resolvePlansPath(dir)
	if got != "" {
		t.Errorf("resolvePlansPath() = %q, want empty string when Plans.md not found", got)
	}
}

// TestResolvePlansPath_WithConfig verifies that when the plansDirectory setting is present,
// the subdirectory's Plans.md path is returned.
func TestResolvePlansPath_WithConfig(t *testing.T) {
	dir := t.TempDir()

	// Create the config file
	configContent := "plansDirectory: docs\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Create docs/Plans.md
	docsDir := filepath.Join(dir, "docs")
	if err := os.MkdirAll(docsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	plansPath := filepath.Join(docsDir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	got := resolvePlansPath(dir)
	if got != plansPath {
		t.Errorf("resolvePlansPath() = %q, want %q", got, plansPath)
	}
}

// TestResolvePlansPath_WithConfig_FileNotExist verifies an empty string is returned with config present but file missing.
func TestResolvePlansPath_WithConfig_FileNotExist(t *testing.T) {
	dir := t.TempDir()

	// Create the config file (create the docs directory but not Plans.md)
	configContent := "plansDirectory: docs\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(dir, "docs"), 0o755); err != nil {
		t.Fatal(err)
	}

	got := resolvePlansPath(dir)
	if got != "" {
		t.Errorf("resolvePlansPath() = %q, want empty string when Plans.md not found in custom dir", got)
	}
}

// TestResolvePlansPath_CaseVariants verifies case variants are detected.
// Because macOS APFS is case-insensitive, we verify the detected path points to an
// existing file (checking existence rather than the exact file name).
func TestResolvePlansPath_CaseVariants(t *testing.T) {
	variants := []string{"plans.md", "PLANS.md", "PLANS.MD"}
	for _, name := range variants {
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			plansPath := filepath.Join(dir, name)
			if err := os.WriteFile(plansPath, []byte("# Plans\n"), 0o644); err != nil {
				t.Fatal(err)
			}

			got := resolvePlansPath(dir)
			// The returned path must exist (works on case-insensitive FS too)
			if got == "" {
				t.Errorf("resolvePlansPath() returned empty for variant %s", name)
				return
			}
			if _, err := os.Stat(got); err != nil {
				t.Errorf("resolvePlansPath() = %q, but file does not exist: %v", got, err)
			}
		})
	}
}

// TestReadPlansDirectoryFromConfig_NormalValue verifies a normal value is read correctly.
func TestReadPlansDirectoryFromConfig_NormalValue(t *testing.T) {
	dir := t.TempDir()
	configContent := "plansDirectory: docs\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := readPlansDirectoryFromConfig(dir)
	if got != "docs" {
		t.Errorf("readPlansDirectoryFromConfig() = %q, want %q", got, "docs")
	}
}

// TestReadPlansDirectoryFromConfig_QuotedValue verifies a quoted value is read correctly.
func TestReadPlansDirectoryFromConfig_QuotedValue(t *testing.T) {
	dir := t.TempDir()
	configContent := `plansDirectory: "my-plans"` + "\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := readPlansDirectoryFromConfig(dir)
	if got != "my-plans" {
		t.Errorf("readPlansDirectoryFromConfig() = %q, want %q", got, "my-plans")
	}
}

// TestReadPlansDirectoryFromConfig_NoConfig verifies an empty string is returned with no config file.
func TestReadPlansDirectoryFromConfig_NoConfig(t *testing.T) {
	dir := t.TempDir()

	got := readPlansDirectoryFromConfig(dir)
	if got != "" {
		t.Errorf("readPlansDirectoryFromConfig() = %q, want empty when no config file", got)
	}
}

// TestReadPlansDirectoryFromConfig_AbsolutePathRejected verifies absolute paths are rejected for security.
func TestReadPlansDirectoryFromConfig_AbsolutePathRejected(t *testing.T) {
	dir := t.TempDir()
	configContent := "plansDirectory: /etc/plans\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := readPlansDirectoryFromConfig(dir)
	if got != "" {
		t.Errorf("readPlansDirectoryFromConfig() = %q, want empty for absolute path (security)", got)
	}
}

// TestReadPlansDirectoryFromConfig_ParentRefRejected verifies values containing .. are rejected for security.
func TestReadPlansDirectoryFromConfig_ParentRefRejected(t *testing.T) {
	dir := t.TempDir()
	configContent := "plansDirectory: ../outside\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := readPlansDirectoryFromConfig(dir)
	if got != "" {
		t.Errorf("readPlansDirectoryFromConfig() = %q, want empty for parent dir reference (security)", got)
	}
}

// TestResolveProjectRoot_EnvVarPriority verifies the environment variable takes top priority.
func TestResolveProjectRoot_EnvVarPriority(t *testing.T) {
	t.Setenv("HARNESS_PROJECT_ROOT", "/custom/root")
	got := resolveProjectRoot()
	if got != "/custom/root" {
		t.Errorf("resolveProjectRoot() = %q, want /custom/root (HARNESS_PROJECT_ROOT)", got)
	}
}

// TestResolveProjectRoot_ProjectRootFallback verifies the PROJECT_ROOT fallback.
func TestResolveProjectRoot_ProjectRootFallback(t *testing.T) {
	t.Setenv("HARNESS_PROJECT_ROOT", "")
	t.Setenv("PROJECT_ROOT", "/project/root")
	got := resolveProjectRoot()
	if got != "/project/root" {
		t.Errorf("resolveProjectRoot() = %q, want /project/root (PROJECT_ROOT)", got)
	}
}

// TestResolveProjectRoot_GitFallback verifies the git rev-parse result is used.
// When HARNESS_PROJECT_ROOT and PROJECT_ROOT are unset, the git toplevel is used.
// This test assumes it runs inside a git repository (including CI environments).
func TestResolveProjectRoot_GitFallback(t *testing.T) {
	t.Setenv("HARNESS_PROJECT_ROOT", "")
	t.Setenv("PROJECT_ROOT", "")

	got := resolveProjectRoot()
	// Inside a git repository it must not be empty
	if got == "" {
		t.Error("resolveProjectRoot() returned empty string; expected a non-empty path")
	}
	// The returned path must exist
	if _, err := os.Stat(got); err != nil {
		t.Errorf("resolveProjectRoot() = %q, but path does not exist: %v", got, err)
	}
	// Must be either the git toplevel or the current directory (starts with a slash)
	if !strings.HasPrefix(got, "/") {
		t.Errorf("resolveProjectRoot() = %q, want absolute path", got)
	}
}

func TestResolveHarnessLocale_DefaultEnNoConfig(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "")

	got := resolveHarnessLocale(dir)
	if got != "en" {
		t.Errorf("resolveHarnessLocale() = %q, want en", got)
	}
}

func TestResolveHarnessLocale_EnvJapanese(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "ja")

	got := resolveHarnessLocale(dir)
	if got != "ja" {
		t.Errorf("resolveHarnessLocale() = %q, want ja", got)
	}
}

func TestResolveHarnessLocale_ConfigPriorityOverEnv(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "en")
	config := "i18n:\n  language: ja\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	got := resolveHarnessLocale(dir)
	if got != "ja" {
		t.Errorf("resolveHarnessLocale() = %q, want ja from config", got)
	}
}

func TestResolveHarnessLocale_InvalidValuesNormalizeToEn(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "ja")
	config := "i18n:\n  language: fr\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	got := resolveHarnessLocale(dir)
	if got != "en" {
		t.Errorf("resolveHarnessLocale() = %q, want invalid config normalized to en", got)
	}
}

func TestResolveHarnessLocale_ExplicitPriority(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "ja")
	config := "i18n:\n  language: ja\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	got := resolveHarnessLocale(dir, "en")
	if got != "en" {
		t.Errorf("resolveHarnessLocale(explicit en) = %q, want en", got)
	}
}
