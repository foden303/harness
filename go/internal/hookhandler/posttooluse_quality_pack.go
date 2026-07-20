package hookhandler

// posttooluse_quality_pack.go
// Go port of posttooluse-quality-pack.sh.
//
// Runs optional quality checks after a PostToolUse Write/Edit:
//   - Load settings from .harness.config.yaml
//   - Prettier check (warn/run mode)
//   - tsc --noEmit check (warn/run mode)
//   - console.log detection
//   - Aggregate each check result into systemMessage (additionalContext)
//   - Skip if the setting is disabled/unset

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
)

// qualityPackInput is the stdin JSON for the PostToolUse hook.
type qualityPackInput struct {
	ToolName  string `json:"tool_name"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
	CWD string `json:"cwd"`
}

// qualityPackConfig is the quality_pack section of .harness.config.yaml.
type qualityPackConfig struct {
	Enabled    bool   // enabled: true/false (default false)
	Mode       string // warn or run (default warn)
	Prettier   bool   // prettier: true/false (default true)
	TSC        bool   // tsc: true/false (default true)
	ConsoleLog bool   // console_log: true/false (default true)
}

// HandlePostToolUseQualityPack is the Go port of posttooluse-quality-pack.sh.
//
// It is invoked on PostToolUse Write/Edit events and runs quality checks.
// It only acts when quality_pack.enabled in .harness.config.yaml is true.
func HandlePostToolUseQualityPack(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return nil
	}

	var input qualityPackInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		return nil
	}

	// Only target Write/Edit
	if input.ToolName != "Write" && input.ToolName != "Edit" {
		return nil
	}

	// Get the file path
	filePath := input.ToolInput.FilePath
	if filePath == "" {
		filePath = input.ToolResponse.FilePath
	}
	if filePath == "" {
		return nil
	}

	// Convert to a relative path if CWD is available
	cwd := input.CWD
	if cwd != "" && strings.HasPrefix(filePath, cwd+"/") {
		filePath = strings.TrimPrefix(filePath, cwd+"/")
	}
	locale := resolveHarnessLocale(cwd)

	// Only target JS/TS files
	if !isJSTSFile(filePath) {
		return nil
	}

	// Check excluded paths
	if isExcludedPath(filePath) {
		return nil
	}

	// Load the settings
	cfg := readQualityPackConfig(".harness.config.yaml")
	if !cfg.Enabled {
		return nil
	}

	// Run quality checks and collect feedback
	var feedbacks []string

	if cfg.Prettier {
		msg := runPrettierCheck(filePath, cfg.Mode, locale)
		if msg != "" {
			feedbacks = append(feedbacks, msg)
		}
	}

	if cfg.TSC {
		msg := runTSCCheck(cfg.Mode, locale)
		if msg != "" {
			feedbacks = append(feedbacks, msg)
		}
	}

	if cfg.ConsoleLog {
		msg := detectConsoleLogs(filePath, locale)
		if msg != "" {
			feedbacks = append(feedbacks, msg)
		}
	}

	if len(feedbacks) == 0 {
		return nil
	}

	// Combine the feedback and output it as additionalContext
	combined := "Quality Pack (PostToolUse)\n" + strings.Join(feedbacks, "\n")

	o := postToolOutput{}
	o.HookSpecificOutput.HookEventName = "PostToolUse"
	o.HookSpecificOutput.AdditionalContext = combined
	return writeJSON(out, o)
}

// isJSTSFile determines whether the file is a JS/TS file.
func isJSTSFile(filePath string) bool {
	lower := strings.ToLower(filePath)
	for _, ext := range []string{".ts", ".tsx", ".js", ".jsx"} {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	return false
}

// isExcludedPath determines whether the path is excluded.
// Equivalent to the bash case statement: .claude/*, docs/*, templates/*, benchmarks/*, node_modules/*, .git/*
func isExcludedPath(filePath string) bool {
	excludePrefixes := []string{
		".claude/",
		"docs/",
		"templates/",
		"benchmarks/",
		"node_modules/",
		".git/",
	}
	for _, prefix := range excludePrefixes {
		if strings.HasPrefix(filePath, prefix) {
			return true
		}
	}
	return false
}

// readQualityPackConfig reads the quality_pack section from .harness.config.yaml.
// Implemented without a YAML parser (logic equivalent to the bash awk).
func readQualityPackConfig(configPath string) qualityPackConfig {
	cfg := qualityPackConfig{
		Enabled:    false,
		Mode:       "warn",
		Prettier:   true,
		TSC:        true,
		ConsoleLog: true,
	}

	f, err := os.Open(configPath)
	if err != nil {
		return cfg // Default (disabled) if the file does not exist
	}
	defer f.Close()

	inQualityPack := false
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()

		// Detect the start of the quality_pack: section
		if strings.TrimSpace(line) == "quality_pack:" {
			inQualityPack = true
			continue
		}

		// Stop when another top-level section begins
		if inQualityPack && len(line) > 0 && line[0] != ' ' && line[0] != '\t' && line[0] != '#' {
			break
		}

		if !inQualityPack {
			continue
		}

		// Parse key: value (indented)
		trimmed := strings.TrimSpace(line)
		parts := strings.SplitN(trimmed, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		val = strings.Trim(val, `"'`)

		switch key {
		case "enabled":
			cfg.Enabled = val == "true"
		case "mode":
			cfg.Mode = val
		case "prettier":
			cfg.Prettier = val != "false"
		case "tsc":
			cfg.TSC = val != "false"
		case "console_log":
			cfg.ConsoleLog = val != "false"
		}
	}

	return cfg
}

// runPrettierCheck runs the Prettier check.
// mode=run: runs prettier --write
// mode=warn: returns a recommendation message
func runPrettierCheck(filePath, mode, locale string) string {
	if mode == "run" {
		prettierBin := "./node_modules/.bin/prettier"
		if _, statErr := os.Stat(prettierBin); statErr != nil {
			return "Prettier: not run (prettier not found)"
		}
		cmd := exec.Command(prettierBin, "--write", filePath)
		var errBuf bytes.Buffer
		cmd.Stderr = &errBuf
		if runErr := cmd.Run(); runErr != nil {
			return "Prettier: not run (prettier not found)"
		}
		return "Prettier: ran"
	}
	// warn mode
	return fmt.Sprintf("Prettier: recommended (example: npx prettier --write %q)", filePath)
}

// runTSCCheck runs the TypeScript type check.
// mode=run: runs tsc --noEmit
// mode=warn: returns a recommendation message
func runTSCCheck(mode, locale string) string {
	if mode == "run" {
		// Check for the existence of tsconfig.json
		if _, statErr := os.Stat("tsconfig.json"); statErr != nil {
			return "tsc --noEmit: not run (tsconfig/tsc not found)"
		}
		tscBin := "./node_modules/.bin/tsc"
		if _, statErr := os.Stat(tscBin); statErr != nil {
			return "tsc --noEmit: not run (tsconfig/tsc not found)"
		}
		cmd := exec.Command(tscBin, "--noEmit")
		if runErr := cmd.Run(); runErr != nil {
			return "tsc --noEmit: not run (tsconfig/tsc not found)"
		}
		return "tsc --noEmit: ran"
	}
	// warn mode
	return "tsc --noEmit: recommended"
}

// detectConsoleLogs detects the number of console.log occurrences in the file.
func detectConsoleLogs(filePath, locale string) string {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return ""
	}

	count := 0
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		if strings.Contains(scanner.Text(), "console.log") {
			count++
		}
	}

	if count > 0 {
		return fmt.Sprintf("Found %d console.log call(s)", count)
	}
	return ""
}
