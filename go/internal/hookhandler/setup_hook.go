package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/foden303/harness/go/internal/harnessmem"
	"github.com/foden303/harness/go/internal/scaffold"
)

// setupInput is the stdin JSON payload of the Setup hook.
type setupInput struct {
	HookEventName string `json:"hook_event_name"`
	SessionID     string `json:"session_id"`
	Mode          string `json:"mode"` // "init" or "maintenance"
}

// setupOutput is the response format of the Setup hook.
type setupOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// writeSetupOutput writes the Setup hook response.
func writeSetupOutput(w io.Writer, message string) error {
	var out setupOutput
	out.HookSpecificOutput.HookEventName = "Setup"
	out.HookSpecificOutput.AdditionalContext = message
	return writeJSON(w, out)
}

// isSimpleMode detects simple mode via the CLAUDE_CODE_SIMPLE environment variable.
// Corresponds to the is_simple_mode() function of check-simple-mode.sh.
func isSimpleMode() bool {
	val := strings.ToLower(os.Getenv("CLAUDE_CODE_SIMPLE"))
	return val == "1" || val == "true" || val == "yes"
}

// runSyncPluginCache runs the plugin cache sync script (if it exists).
func runSyncPluginCache(scriptDir string) {
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		_ = cmd.Run() // ignore errors
	}
}

// getPlansFilePath gets the Plans.md path from the config.
// A Go-native implementation using resolvePlansPath() from helpers.go.
// It removes the dependency on bash (config-utils.sh).
func getPlansFilePath(_ string) string {
	projectRoot := resolveProjectRoot()
	if path := resolvePlansPath(projectRoot); path != "" {
		return path
	}
	return filepath.Join(projectRoot, "Plans.md")
}

// runTemplateTracker runs the template tracker script.
func runTemplateTracker(scriptDir, action string) string {
	trackerScript := filepath.Join(scriptDir, "template-tracker.sh")
	if _, err := os.Stat(trackerScript); err == nil {
		cmd := exec.Command("bash", trackerScript, action)
		if out, err := cmd.Output(); err == nil {
			return strings.TrimSpace(string(out))
		}
	}
	return ""
}

// HandleSetupHookInit is a Go port of the init mode of setup-hook.sh.
//
// As the initial setup, it performs the following:
//  1. Sync the plugin cache
//  2. Initialize the .claude/state/ directory
//  3. Generate the default config file (if it does not exist)
//  4. Generate CLAUDE.md (if it does not exist)
//  5. Generate Plans.md (if it does not exist)
//  6. Initialize the template tracker
func HandleSetupHookInit(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "init")
}

// HandleSetupHookMaintenance is a Go port of the maintenance mode of setup-hook.sh.
//
// As maintenance processing, it performs the following:
//  1. Sync the plugin cache
//  2. Remove old session archives older than 7 days
//  3. Remove .tmp files
//  4. Check for template updates
//  5. Validate the YAML syntax of the config file
func HandleSetupHookMaintenance(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "maintenance")
}

// HandleSetupHook is a Go port of the entire setup-hook.sh.
// It determines the mode from the stdin JSON payload or arguments.
func HandleSetupHook(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "")
}

// handleSetupHook is the internal implementation of setup-hook.sh.
// If mode is empty, it is determined from the stdin payload.
func handleSetupHook(in io.Reader, out io.Writer, mode string) error {
	// Detect SIMPLE mode
	simpleMode := isSimpleMode()
	if simpleMode {
		fmt.Fprintf(os.Stderr, "[WARNING] CLAUDE_CODE_SIMPLE mode detected — skills/agents/memory disabled\n")
	}

	// Read JSON from stdin (ignore errors)
	data, _ := io.ReadAll(in)

	// Determine the mode from the payload (arguments take precedence)
	if mode == "" {
		var input setupInput
		if len(data) > 0 {
			_ = json.Unmarshal(data, &input)
		}
		if input.Mode != "" {
			mode = input.Mode
		} else {
			mode = "init"
		}
	}

	// Infer the script directory (based on the running binary; cwd during tests)
	scriptDir := resolveSetupScriptDir()
	locale := resolveHarnessLocale(resolveProjectRoot())

	switch mode {
	case "init":
		return runSetupInit(out, scriptDir, simpleMode, locale)
	case "maintenance":
		return runSetupMaintenance(out, scriptDir, simpleMode, locale)
	default:
		return writeSetupOutput(out, setupUnknownModeMessage(mode, locale))
	}
}

func setupUnknownModeMessage(mode, locale string) string {
	return fmt.Sprintf("[Setup] unknown mode: %s", mode)
}

// resolveSetupScriptDir resolves the script directory path.
// Since the hook runs in the target project's CWD, a CWD-based search does not
// point to the harness install location. It resolves in the following priority order:
//
//  1. CLAUDE_PLUGIN_ROOT environment variable (harness install location)
//  2. HARNESS_SCRIPT_DIR environment variable (explicit override)
//  3. CWD (fallback for development environments)
func resolveSetupScriptDir() string {
	if root := os.Getenv("CLAUDE_PLUGIN_ROOT"); root != "" {
		return filepath.Join(root, "scripts")
	}
	if dir := os.Getenv("HARNESS_SCRIPT_DIR"); dir != "" {
		return dir
	}
	// Fallback: scripts/ in the current directory (for development environments)
	cwd, _ := os.Getwd()
	return filepath.Join(cwd, "scripts")
}

// runSetupInit runs the init-mode processing.
func runSetupInit(out io.Writer, scriptDir string, simpleMode bool, locale string) error {
	var messages []string

	// 1. Sync the plugin cache
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		if err := cmd.Run(); err == nil {
			messages = append(messages, "plugin cache synced")
		}
	}

	// 2. Initialize the state directory
	stateDir := ".claude/state"
	if err := os.MkdirAll(stateDir, 0o755); err == nil {
		// Initialization succeeded (OK if it already exists)
	}

	// 3. Generate the default config file
	configFile := ".harness.config.yaml"
	if !fileExists(configFile) {
		templatePath := filepath.Join(scriptDir, "..", "templates", ".harness.config.yaml.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, configFile); err == nil {
				messages = append(messages, "config file created")
			}
		}
	}

	// 3.5. Generate harness.toml
	if !fileExists("harness.toml") {
		if err := os.WriteFile("harness.toml", []byte(scaffold.HarnessTomlTemplate), 0o644); err == nil {
			messages = append(messages, "harness.toml created")
		}
	}

	// 4. Generate CLAUDE.md
	if !fileExists("CLAUDE.md") {
		templatePath := filepath.Join(scriptDir, "..", "templates", "CLAUDE.md.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, "CLAUDE.md"); err == nil {
				messages = append(messages, "CLAUDE.md created")
			}
		}
	}

	// 5. Generate Plans.md (taking the plansDirectory setting into account)
	plansPath := getPlansFilePath(scriptDir)
	if !fileExists(plansPath) {
		plansDir := filepath.Dir(plansPath)
		if plansDir != "." {
			_ = os.MkdirAll(plansDir, 0o755)
		}
		templatePath := filepath.Join(scriptDir, "..", "templates", "Plans.md.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, plansPath); err == nil {
				messages = append(messages, "Plans.md created")
			}
		}
	}

	// 6. Initialize the template tracker
	runTemplateTracker(scriptDir, "init")

	// 7. Auto-setup of the harness-mem managed companion.
	// Even if it fails, the main Harness Setup hook is not stopped.
	if result := harnessmem.AutoSetupFromSetupHook(harnessMemAutoSetupMarkerPath()); result.Attempted {
		if result.Ready {
			messages = append(messages, "harness-mem companion setup complete")
		} else {
			messages = append(messages, "harness-mem companion setup deferred")
		}
	} else if result.Ready {
		messages = append(messages, "harness-mem companion ready")
	}

	// Add the SIMPLE mode warning
	if simpleMode {
		messages = append(messages, "WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
	}

	if len(messages) == 0 {
		return writeSetupOutput(out, "[Setup:init] harness is already initialized")
	}
	return writeSetupOutput(out, "[Setup:init] "+strings.Join(messages, ", "))
}

func harnessMemAutoSetupMarkerPath() string {
	projectRoot := resolveProjectRoot()
	return filepath.Join(projectRoot, ".claude", "state", "harness-mem-companion-setup.json")
}

// runSetupMaintenance runs the maintenance-mode processing.
func runSetupMaintenance(out io.Writer, scriptDir string, simpleMode bool, locale string) error {
	var messages []string

	// 1. Sync the plugin cache
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		if err := cmd.Run(); err == nil {
			messages = append(messages, "cache synced")
		}
	}

	// 2. Clean up old session files (7 days or older)
	stateDir := ".claude/state"
	archiveDir := filepath.Join(stateDir, "sessions")
	if _, err := os.Stat(archiveDir); err == nil {
		cutoff := time.Now().AddDate(0, 0, -7)
		entries, err := os.ReadDir(archiveDir)
		if err == nil {
			for _, entry := range entries {
				if !strings.HasPrefix(entry.Name(), "session-") || !strings.HasSuffix(entry.Name(), ".json") {
					continue
				}
				info, err := entry.Info()
				if err != nil {
					continue
				}
				if info.ModTime().Before(cutoff) {
					_ = os.Remove(filepath.Join(archiveDir, entry.Name()))
				}
			}
		}
		messages = append(messages, "old session archives removed")
	}

	// 3. Clean up temporary files
	if _, err := os.Stat(stateDir); err == nil {
		removeTmpFiles(stateDir)
	}

	// 4. Check for template updates
	checkResult := runTemplateTracker(scriptDir, "check")
	if checkResult != "" {
		var checkData map[string]interface{}
		if err := json.Unmarshal([]byte(checkResult), &checkData); err == nil {
			if needsCheck, ok := checkData["needsCheck"].(bool); ok && needsCheck {
				updatesCount := 0
				if count, ok := checkData["updatesCount"].(float64); ok {
					updatesCount = int(count)
				}
				messages = append(messages, fmt.Sprintf("template updates available: %d", updatesCount))
			}
		}
	}

	// 5. Add the SIMPLE mode warning
	if simpleMode {
		messages = append(messages, "WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
	}

	// 6. Check the YAML syntax of the config file (if python3 is available)
	configFile := ".harness.config.yaml"
	if fileExists(configFile) {
		if err := validateYAMLConfig(configFile); err != nil {
			messages = append(messages, "warning: config file syntax error")
		}
	}

	if len(messages) == 0 {
		return writeSetupOutput(out, "[Setup:maintenance] maintenance complete (no changes)")
	}
	return writeSetupOutput(out, "[Setup:maintenance] "+strings.Join(messages, ", "))
}

// copyFile copies a file.
func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("read %s: %w", src, err)
	}
	return os.WriteFile(dst, data, 0o644)
}

// removeTmpFiles recursively removes .tmp files within a directory.
func removeTmpFiles(dir string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		if entry.IsDir() {
			removeTmpFiles(path)
			continue
		}
		if strings.HasSuffix(entry.Name(), ".tmp") {
			_ = os.Remove(path)
		}
	}
}

// validateYAMLConfig validates YAML syntax using python3.
func validateYAMLConfig(configFile string) error {
	if _, err := exec.LookPath("python3"); err != nil {
		return nil // skip if python3 is not available
	}
	cmd := newYAMLValidationCommand(configFile)
	return cmd.Run()
}

func newYAMLValidationCommand(configFile string) *exec.Cmd {
	return exec.Command("python3", "-c", "import sys, yaml; yaml.safe_load(open(sys.argv[1]))", configFile)
}
