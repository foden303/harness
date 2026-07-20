package hookhandler

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// autoTestRunnerInput is the stdin JSON passed from the PostToolUse hook.
type autoTestRunnerInput struct {
	ToolName  string `json:"tool_name"`
	CWD       string `json:"cwd"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
}

// autoTestResult is the struct written to .claude/state/test-result.json.
type autoTestResult struct {
	Timestamp   string `json:"timestamp"`
	ChangedFile string `json:"changed_file"`
	Command     string `json:"command"`
	Status      string `json:"status"`
	ExitCode    int    `json:"exit_code"`
	Output      string `json:"output"`
}

// autoTestRecommendation is the struct written to .claude/state/test-recommendation.json.
type autoTestRecommendation struct {
	Timestamp      string `json:"timestamp"`
	ChangedFile    string `json:"changed_file"`
	TestCommand    string `json:"test_command"`
	RelatedTest    string `json:"related_test"`
	Recommendation string `json:"recommendation"`
}

type autoTestCommandInvocation struct {
	Name    string
	Args    []string
	Display string
}

// autoTestHookOutput is the hookSpecificOutput carrying additionalContext.
type autoTestHookOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// sourceFileExtensions are file extensions that require running tests.
var sourceFileExtensions = []string{
	".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".rs",
}

// excludedDirs are directory prefixes excluded from test targets.
var excludedDirs = []string{
	"node_modules/",
	"dist/",
	"build/",
	".next/",
}

// excludedExtensions are file extensions excluded from test targets.
var excludedExtensions = []string{
	".md", ".json", ".yml", ".yaml", ".lock",
}

// HandleAutoTestRunner is the Go port of auto-test-runner.sh.
//
// It detects source file changes on PostToolUse Write/Edit events, auto-detects
// the test framework, and runs the tests.
//
// Modes:
//   - HARNESS_AUTO_TEST=run → actually run the tests and notify via additionalContext
//   - default (recommend) → record a test recommendation in .claude/state/
func HandleAutoTestRunner(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(bytes.TrimSpace(data)) == 0 {
		return emptyPostToolOutput(out)
	}

	var input autoTestRunnerInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	// Get the changed file
	changedFile := input.ToolInput.FilePath
	if changedFile == "" {
		changedFile = input.ToolResponse.FilePath
	}
	if changedFile == "" {
		return emptyPostToolOutput(out)
	}

	// Normalize to a project-relative path
	changedFile = normalizePathSeparators(changedFile)
	if input.CWD != "" {
		cwd := normalizePathSeparators(input.CWD)
		changedFile = makeRelativePath(changedFile, cwd)
	}

	// Determine the project root (CWD or the current directory)
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	// Decide whether tests need to run
	if !shouldRunTests(changedFile) {
		return emptyPostToolOutput(out)
	}

	// Detect the test command
	testCmd := detectTestCommand(projectRoot)
	if testCmd == "" {
		return emptyPostToolOutput(out)
	}

	// Find related test files (P2 fix: pass projectRoot)
	relatedTest := findRelatedTests(changedFile, projectRoot)

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return emptyPostToolOutput(out)
	}

	// When HARNESS_AUTO_TEST=run, actually run the tests
	if os.Getenv("HARNESS_AUTO_TEST") == "run" {
		return runTestsAndReport(out, projectRoot, stateDir, changedFile, testCmd, relatedTest)
	}

	// Default: recommend mode
	return writeTestRecommendation(out, stateDir, changedFile, testCmd, relatedTest)
}

// shouldRunTests decides whether a file change should trigger a test run.
func shouldRunTests(file string) bool {
	if file == "" {
		return false
	}

	// Excluded directory check
	for _, dir := range excludedDirs {
		if strings.HasPrefix(file, dir) {
			return false
		}
	}

	// Excluded extension check
	for _, ext := range excludedExtensions {
		if strings.HasSuffix(file, ext) {
			return false
		}
	}

	// .gitignore
	if file == ".gitignore" {
		return false
	}

	// Change to a test file itself
	if strings.Contains(file, ".test.") || strings.Contains(file, ".spec.") || strings.Contains(file, "__tests__") {
		return true
	}

	// Change to a source code file
	for _, ext := range sourceFileExtensions {
		if strings.HasSuffix(file, ext) {
			return true
		}
	}

	return false
}

// detectTestCommand auto-detects the test command from the project root.
//
// Detection priority (P2 fix: ordered JS framework → Python → Rust → Go, and the
// tests/ pytest heuristic applies only when there is no package.json):
//  1. vitest.config.* → npx vitest run --reporter=verbose
//  2. jest.config.* → npx jest --verbose
//  3. jest key in package.json / jest in scripts.test → npx jest --verbose
//  4. scripts.test in package.json (npm test fallback) → npm test
//  5. pytest.ini → pytest -v
//  6. [tool.pytest] in pyproject.toml → pytest -v
//  7. tests/ directory (only when there is no package.json) → pytest -v
//  8. Cargo.toml → cargo test
//  9. go.mod → go test ./...
func detectTestCommand(projectRoot string) string {
	// vitest
	vitestConfigs := []string{
		"vitest.config.ts", "vitest.config.js", "vitest.config.mts", "vitest.config.mjs",
	}
	for _, cfg := range vitestConfigs {
		if autoTestFileExists(filepath.Join(projectRoot, cfg)) {
			return "npx vitest run --reporter=verbose"
		}
	}

	// jest: detection via config file (no false positives)
	jestConfigs := []string{
		"jest.config.ts", "jest.config.js", "jest.config.mjs", "jest.config.cjs",
	}
	for _, cfg := range jestConfigs {
		if autoTestFileExists(filepath.Join(projectRoot, cfg)) {
			return "npx jest --verbose"
		}
	}

	// Detection for JS/Node projects that have a package.json.
	// Handle the jest check and the npm test fallback together, and check
	// package.json first to prevent the tests/ pytest misdetection (P2).
	pkgPath := filepath.Join(projectRoot, "package.json")
	hasPkgJSON := autoTestFileExists(pkgPath)
	if hasPkgJSON {
		content, err := os.ReadFile(pkgPath)
		if err == nil {
			// jest: detection by JSON-parsing package.json.
			// Treat as Jest only when a top-level "jest" key exists as an object,
			// or when scripts.test contains "jest".
			// Prevents false positives from dependency names like @types/jest or jest-junit.
			if hasJestConfig(content) {
				return "npx jest --verbose"
			}
			// npm test fallback
			if hasNpmTestScript(content) {
				return "npm test"
			}
		}
	}

	// pytest-family frameworks: return only when the pytest binary exists on PATH.
	// A framework config file may exist in an environment where pytest is not
	// installed, so check with LookPath beforehand since the command could not run.
	if _, pytestErr := exec.LookPath("pytest"); pytestErr == nil {
		// pytest.ini
		if autoTestFileExists(filepath.Join(projectRoot, "pytest.ini")) {
			return "pytest -v"
		}
		// [tool.pytest] in pyproject.toml
		pyprojectPath := filepath.Join(projectRoot, "pyproject.toml")
		if autoTestFileExists(pyprojectPath) {
			content, err := os.ReadFile(pyprojectPath)
			if err == nil && bytes.Contains(content, []byte("[tool.pytest")) {
				return "pytest -v"
			}
		}
		// Python project with a tests/ directory (no config file).
		// Does not apply to JS projects that have a package.json.
		if !hasPkgJSON {
			if autoTestFileExists(filepath.Join(projectRoot, "tests")) {
				if info, err := os.Stat(filepath.Join(projectRoot, "tests")); err == nil && info.IsDir() {
					return "pytest -v"
				}
			}
		}
	}

	// Rust project with a Cargo.toml
	if autoTestFileExists(filepath.Join(projectRoot, "Cargo.toml")) {
		return "cargo test"
	}

	// go test: check whether go.mod exists
	if autoTestFileExists(filepath.Join(projectRoot, "go.mod")) {
		return "go test ./..."
	}

	return ""
}

// hasJestConfig checks by JSON-parsing package.json whether Jest is configured.
//
// Returns true when either of the following holds:
//   - a top-level "jest" key exists as an object (a Jest config object)
//   - the value of scripts.test contains the string "jest"
//
// Prevents false positives from a naive substring search over dependency names like @types/jest or jest-junit.
func hasJestConfig(content []byte) bool {
	var pkg map[string]json.RawMessage
	if err := json.Unmarshal(content, &pkg); err != nil {
		return false
	}

	// Check whether the "jest" key exists as a top-level object
	if jestRaw, ok := pkg["jest"]; ok {
		// Check whether the value is an object (a Jest config)
		var jestObj map[string]json.RawMessage
		if json.Unmarshal(jestRaw, &jestObj) == nil {
			return true
		}
	}

	// Check whether scripts.test contains "jest"
	scriptsRaw, ok := pkg["scripts"]
	if !ok {
		return false
	}
	var scripts map[string]interface{}
	if err := json.Unmarshal(scriptsRaw, &scripts); err != nil {
		return false
	}
	if testVal, ok := scripts["test"]; ok {
		if testStr, ok := testVal.(string); ok && strings.Contains(testStr, "jest") {
			return true
		}
	}

	return false
}

// hasNpmTestScript checks whether scripts.test is defined in package.json.
func hasNpmTestScript(content []byte) bool {
	var pkg map[string]json.RawMessage
	if err := json.Unmarshal(content, &pkg); err != nil {
		return false
	}
	scriptsRaw, ok := pkg["scripts"]
	if !ok {
		return false
	}
	var scripts map[string]interface{}
	if err := json.Unmarshal(scriptsRaw, &scripts); err != nil {
		return false
	}
	testVal, ok := scripts["test"]
	if !ok {
		return false
	}
	// Even if a "test" key exists, exclude empty strings and the npm init placeholder
	testStr, ok := testVal.(string)
	if !ok || strings.TrimSpace(testStr) == "" {
		return false
	}
	// Do not treat the default value generated by npm init as having tests
	if strings.Contains(testStr, "Error: no test specified") {
		return false
	}
	return true
}

// findRelatedTests looks for the test file corresponding to the changed file.
//
// P2 fix: it takes projectRoot, and when the file is a relative path it searches
// for test files relative to filepath.Join(projectRoot, file).
// This detects tests correctly even when the harness binary is launched from outside the repo root.
func findRelatedTests(file, projectRoot string) string {
	// If file is not an absolute path, join it with projectRoot to get an
	// absolute path and use it as the basis for pattern generation.
	absFile := file
	if !filepath.IsAbs(file) && projectRoot != "" {
		absFile = filepath.Join(projectRoot, file)
	}

	ext := filepath.Ext(absFile)
	basename := strings.TrimSuffix(absFile, ext)
	dirname := filepath.Dir(absFile)
	baseName := filepath.Base(basename)

	patterns := []string{
		basename + ".test.ts",
		basename + ".test.tsx",
		basename + ".test.js",
		basename + ".test.jsx",
		basename + ".spec.ts",
		basename + ".spec.tsx",
		basename + ".spec.js",
		basename + ".spec.jsx",
		filepath.Join(dirname, "__tests__", baseName+".test.ts"),
		filepath.Join(dirname, "__tests__", baseName+".test.tsx"),
		filepath.Join(dirname, "test_"+baseName+".py"),
		basename + "_test.go",
	}

	for _, pattern := range patterns {
		if autoTestFileExists(pattern) {
			return pattern
		}
	}
	return ""
}

// buildExecCommand returns the exec command, branching per test runner on how the file argument is passed.
//
// P1 fix: `go test` does not accept a `-- <file>` argument, so branch per runner.
//
//   - go test    : go test ./path/to/pkg/... (converted to a package path)
//   - pytest     : pytest path/to/test_file.py
//   - cargo test : cargo test (no file argument)
//   - jest/vitest: npx jest -- path/to/test.ts / npx vitest run -- path/to/test.ts
//   - npm test   : npm test (no file argument)
func buildExecCommand(testCmd, relatedTest, projectRoot string) string {
	return buildExecInvocation(testCmd, relatedTest, projectRoot).Display
}

func buildExecInvocation(testCmd, relatedTest, projectRoot string) autoTestCommandInvocation {
	if relatedTest == "" {
		return invocationFromKnownTestCommand(testCmd)
	}

	switch {
	case strings.HasPrefix(testCmd, "go test"):
		// go test takes a <package path> as its argument.
		// If relatedTest is absolute, convert it back to a path relative to projectRoot and then to a package path.
		rel := relatedTest
		if filepath.IsAbs(relatedTest) && projectRoot != "" {
			if r, err := filepath.Rel(projectRoot, relatedTest); err == nil {
				rel = r
			}
		}
		// Generate the package path of the directory the _test.go file belongs to.
		// e.g. internal/foo/bar_test.go -> go test ./internal/foo/...
		return newAutoTestInvocation("go", []string{"test", goTestPackageArg(rel)})

	case strings.HasPrefix(testCmd, "pytest"):
		// pytest can take the file path directly as an argument.
		return newAutoTestInvocation("pytest", []string{"-v", relatedTest})

	case strings.HasPrefix(testCmd, "cargo test"):
		// cargo test does not support per-file selection, so run it without a file argument.
		return newAutoTestInvocation("cargo", []string{"test"})

	case strings.HasPrefix(testCmd, "npx jest"),
		strings.HasPrefix(testCmd, "npx vitest"):
		// jest/vitest can narrow to a test file with the `-- <file>` form.
		inv := invocationFromKnownTestCommand(testCmd)
		inv.Args = append(inv.Args, "--", relatedTest)
		inv.Display = displayCommand(inv.Name, inv.Args)
		return inv

	case strings.HasPrefix(testCmd, "npm test"):
		// npm test has no well-defined interface for file selection, so run it without a file argument.
		return newAutoTestInvocation("npm", []string{"test"})

	default:
		// For unknown runners, fail safe by running without a file argument.
		return invocationFromKnownTestCommand(testCmd)
	}
}

func goTestPackageArg(relatedTest string) string {
	pkgDir := filepath.ToSlash(filepath.Dir(relatedTest))
	pkgDir = strings.TrimPrefix(pkgDir, "./")
	if pkgDir == "." || pkgDir == "" {
		return "./..."
	}
	return "./" + pkgDir + "/..."
}

func invocationFromKnownTestCommand(testCmd string) autoTestCommandInvocation {
	switch testCmd {
	case "npx vitest run --reporter=verbose":
		return newAutoTestInvocation("npx", []string{"vitest", "run", "--reporter=verbose"})
	case "npx jest --verbose":
		return newAutoTestInvocation("npx", []string{"jest", "--verbose"})
	case "pytest -v":
		return newAutoTestInvocation("pytest", []string{"-v"})
	case "cargo test":
		return newAutoTestInvocation("cargo", []string{"test"})
	case "go test ./...":
		return newAutoTestInvocation("go", []string{"test", "./..."})
	case "npm test":
		return newAutoTestInvocation("npm", []string{"test"})
	default:
		fields := strings.Fields(testCmd)
		if len(fields) == 0 {
			return autoTestCommandInvocation{}
		}
		return newAutoTestInvocation(fields[0], fields[1:])
	}
}

func newAutoTestInvocation(name string, args []string) autoTestCommandInvocation {
	return autoTestCommandInvocation{
		Name:    name,
		Args:    args,
		Display: displayCommand(name, args),
	}
}

func displayCommand(name string, args []string) string {
	parts := append([]string{name}, args...)
	return strings.Join(parts, " ")
}

// runTestsAndReport runs the tests, records the result, and notifies via additionalContext.
func runTestsAndReport(out io.Writer, projectRoot, stateDir, changedFile, testCmd, relatedTest string) error {
	// Determine the exec command (P1 fix: branch the file argument per runner)
	invocation := buildExecInvocation(testCmd, relatedTest, projectRoot)
	execCmd := invocation.Display

	ts := time.Now().UTC().Format(time.RFC3339)

	// Run the tests with a timeout (max 60 seconds)
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, invocation.Name, invocation.Args...)
	cmd.Dir = projectRoot

	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf

	runErr := cmd.Run()
	exitCode := 0
	status := "passed"

	if ctx.Err() == context.DeadlineExceeded {
		exitCode = 124
		status = "timeout"
	} else if runErr != nil {
		if exitErr, ok := runErr.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = 1
		}
		status = "failed"
	}

	// Limit output to at most 200 lines
	output := limitLines(buf.String(), 200)

	// Write out the result as JSON
	resultPath := filepath.Join(stateDir, "test-result.json")
	result := autoTestResult{
		Timestamp:   ts,
		ChangedFile: changedFile,
		Command:     execCmd,
		Status:      status,
		ExitCode:    exitCode,
		Output:      output,
	}
	if err := autoTestWriteJSONFile(resultPath, result); err != nil {
		fmt.Fprintf(os.Stderr, "[auto-test-runner] write result: %v\n", err)
	}

	// Build additionalContext
	var contextMsg string
	outputSnippet := limitLines(output, 30)

	switch status {
	case "passed":
		contextMsg = fmt.Sprintf(
			"[Auto Test Runner] Tests passed\nCommand: %s\nFile: %s\nStatus: PASSED (exit=0)",
			testCmd, changedFile)
	case "timeout":
		contextMsg = fmt.Sprintf(
			"[Auto Test Runner] Tests timed out (60s)\nCommand: %s\nFile: %s\nStatus: TIMEOUT\n\nOutput:\n%s",
			testCmd, changedFile, outputSnippet)
	default:
		contextMsg = fmt.Sprintf(
			"[Auto Test Runner] Tests failed\nCommand: %s\nFile: %s\nStatus: FAILED (exit=%d)\n\nOutput:\n%s\n\nFix the implementation to make the tests pass.",
			testCmd, changedFile, exitCode, outputSnippet)
	}

	var hookOut autoTestHookOutput
	hookOut.HookSpecificOutput.HookEventName = "PostToolUse"
	hookOut.HookSpecificOutput.AdditionalContext = contextMsg

	return json.NewEncoder(out).Encode(hookOut)
}

// writeTestRecommendation records a test recommendation (recommend mode).
func writeTestRecommendation(out io.Writer, stateDir, changedFile, testCmd, relatedTest string) error {
	ts := time.Now().UTC().Format(time.RFC3339)
	recPath := filepath.Join(stateDir, "test-recommendation.json")
	rec := autoTestRecommendation{
		Timestamp:      ts,
		ChangedFile:    changedFile,
		TestCommand:    testCmd,
		RelatedTest:    relatedTest,
		Recommendation: "Running tests is recommended",
	}
	if err := autoTestWriteJSONFile(recPath, rec); err != nil {
		fmt.Fprintf(os.Stderr, "[auto-test-runner] write recommendation: %v\n", err)
	}

	// In recommend mode, return an empty PostToolUse output
	return emptyPostToolOutput(out)
}

// autoTestFileExists checks whether a file exists.
func autoTestFileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// limitLines limits text to at most n lines.
func limitLines(text string, n int) string {
	scanner := bufio.NewScanner(strings.NewReader(text))
	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
		if len(lines) >= n {
			break
		}
	}
	return strings.Join(lines, "\n")
}

// autoTestWriteJSONFile JSON-encodes v and writes it to a file.
func autoTestWriteJSONFile(path string, v interface{}) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		return fmt.Errorf("write: %w", err)
	}
	return nil
}
