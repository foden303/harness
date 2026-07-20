package hookhandler

// helpers.go - shared utility functions for the hookhandler package.
//
// Consolidates local functions that were duplicated across multiple handlers.

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/foden303/harness/go/internal/gitport"
)

// fileExists reports whether the file exists.
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// isSymlink reports whether the path is a symlink (false if it does not exist).
func isSymlink(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeSymlink != 0
}

// rotateJSONL truncates the JSONL file to keepLines lines when it exceeds maxLines.
// Returns nil if the file does not exist (no error).
// Writing to a symlink is refused and returns an error.
func rotateJSONL(path string, maxLines, keepLines int) error {
	if isSymlink(path) || isSymlink(path+".tmp") {
		return fmt.Errorf("symlinked file refused for rotation")
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil // ignore if the file does not exist
	}

	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) <= maxLines {
		return nil
	}

	// Keep the last keepLines lines.
	start := len(lines) - keepLines
	if start < 0 {
		start = 0
	}
	trimmed := strings.Join(lines[start:], "\n") + "\n"

	tmpPath := path + ".tmp"
	if writeErr := os.WriteFile(tmpPath, []byte(trimmed), 0o644); writeErr != nil {
		return fmt.Errorf("write tmp file: %w", writeErr)
	}
	return os.Rename(tmpPath, path)
}

// firstNonEmpty returns the first non-empty string among its arguments.
// Returns "" if all are empty.
func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

// writeJSON writes an arbitrary value to w as JSON.
func writeJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshal JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}

// preToolAllowOutput matches the hookSpecificOutput format for PreToolUse.
type preToolAllowOutput struct {
	HookSpecificOutput struct {
		HookEventName      string `json:"hookEventName"`
		PermissionDecision string `json:"permissionDecision"`
		AdditionalContext  string `json:"additionalContext,omitempty"`
	} `json:"hookSpecificOutput"`
}

// postToolOutput is a PostToolUse hook response envelope.
type postToolOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// emptyPostToolOutput returns a PostToolUse response with no additional context.
func emptyPostToolOutput(w io.Writer) error {
	out := postToolOutput{}
	out.HookSpecificOutput.HookEventName = "PostToolUse"
	out.HookSpecificOutput.AdditionalContext = ""
	return writeJSON(w, out)
}

// resolveProjectRoot returns the project root directory.
//
// Resolution priority:
//  1. HARNESS_PROJECT_ROOT environment variable
//  2. PROJECT_ROOT environment variable
//  3. git rev-parse --show-toplevel (handles monorepo subdirs)
//  4. current directory (fallback)
//
// Equivalent to detect_project_root() in the bash path-utils.sh / config-utils.sh.
func resolveProjectRoot() string {
	if v := os.Getenv("HARNESS_PROJECT_ROOT"); v != "" {
		return v
	}
	if v := os.Getenv("PROJECT_ROOT"); v != "" {
		return v
	}
	// Detect the repository root via git rev-parse --show-toplevel.
	// Ensures .claude/ is found even when run from a monorepo subdirectory.
	if out, err := gitport.Output("", "rev-parse", "--show-toplevel"); err == nil {
		if root := strings.TrimSpace(out); root != "" {
			return root
		}
	}
	cwd, _ := os.Getwd()
	return cwd
}

// harnessConfigFileName is the default config file name.
const harnessConfigFileName = ".harness.config.yaml"

func normalizeHarnessLocale(value string) string {
	normalized := strings.ToLower(strings.Trim(strings.TrimSpace(value), `"'`))
	switch normalized {
	case "en", "ja":
		return normalized
	default:
		return "en"
	}
}

// readI18nLanguageFromConfig returns the i18n.language value from the config file
// under projectRoot. Returns an empty string if unset or unreadable.
func readI18nLanguageFromConfig(projectRoot string) string {
	configPath := filepath.Join(projectRoot, harnessConfigFileName)
	f, err := os.Open(configPath)
	if err != nil {
		return ""
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	inI18n := false
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		if !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
			inI18n = strings.HasPrefix(trimmed, "i18n:")
			continue
		}
		if !inI18n || !strings.HasPrefix(trimmed, "language:") {
			continue
		}

		value := strings.TrimSpace(strings.TrimPrefix(trimmed, "language:"))
		if idx := strings.Index(value, "#"); idx >= 0 {
			value = strings.TrimSpace(value[:idx])
		}
		return strings.Trim(value, `"'`)
	}
	return ""
}

// resolveHarnessLocale resolves the Harness display locale.
//
// Priority:
//  1. explicit locale argument
//  2. i18n.language in .harness.config.yaml
//  3. CLAUDE_CODE_HARNESS_LANG
//  4. en
//
// Anything other than en / ja is normalized to the safe default en.
func resolveHarnessLocale(projectRoot string, explicitLocale ...string) string {
	if len(explicitLocale) > 0 && explicitLocale[0] != "" {
		return normalizeHarnessLocale(explicitLocale[0])
	}
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	if configLocale := readI18nLanguageFromConfig(projectRoot); configLocale != "" {
		return normalizeHarnessLocale(configLocale)
	}
	if envLocale := os.Getenv("CLAUDE_CODE_HARNESS_LANG"); envLocale != "" {
		return normalizeHarnessLocale(envLocale)
	}
	return "en"
}

// readPlansDirectoryFromConfig returns the plansDirectory value from the config
// file under projectRoot. Returns an empty string if unset or unreadable.
//
// To avoid importing a YAML parser, it falls back as follows:
//  1. Scan for a "plansDirectory: <value>" line with bufio.Scanner
//
// Security: the following values fall back to the default (empty string) for safety:
//   - absolute paths (starting with /)
//   - parent-directory references (containing ..)
func readPlansDirectoryFromConfig(projectRoot string) string {
	configPath := filepath.Join(projectRoot, harnessConfigFileName)
	f, err := os.Open(configPath)
	if err != nil {
		return ""
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		// Find lines starting with "plansDirectory:".
		const key = "plansDirectory:"
		if !strings.HasPrefix(line, key) {
			continue
		}
		value := strings.TrimSpace(line[len(key):])
		// Remove quotes (single and double).
		value = strings.Trim(value, `"'`)
		value = strings.TrimSpace(value)

		if value == "" {
			return ""
		}
		// Security: reject absolute paths.
		if filepath.IsAbs(value) {
			return ""
		}
		// Security: reject parent-directory references.
		if strings.Contains(value, "..") {
			return ""
		}
		return value
	}
	return ""
}

// resolvePlansPath returns the full path of Plans.md under projectRoot.
//
// Resolution logic:
//  1. Read plansDirectory from the config file (.harness.config.yaml)
//  2. If set, return filepath.Join(projectRoot, plansDirectory, "Plans.md")
//  3. Otherwise return filepath.Join(projectRoot, "Plans.md")
//  4. Return an empty string if the file does not exist
//
// Equivalent to get_plans_file_path() in the bash version.
func resolvePlansPath(projectRoot string) string {
	// Get plansDirectory from config.
	plansDir := readPlansDirectoryFromConfig(projectRoot)

	// Candidate file names (same case variations as the bash version).
	candidates := []string{"Plans.md", "plans.md", "PLANS.md", "PLANS.MD"}

	var baseDir string
	if plansDir != "" {
		baseDir = filepath.Join(projectRoot, plansDir)
	} else {
		baseDir = projectRoot
	}

	for _, name := range candidates {
		full := filepath.Join(baseDir, name)
		if _, err := os.Stat(full); err == nil {
			return full
		}
	}

	// Return an empty string if none exists (equivalent to bash plans_file_exists()).
	return ""
}
