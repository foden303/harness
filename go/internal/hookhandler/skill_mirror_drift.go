package hookhandler

import (
	"encoding/json"
	"io"
	"path/filepath"
	"strings"

	"github.com/foden303/harness/go/internal/clientmirror"
)

type skillMirrorDriftInput struct {
	ToolName  string `json:"tool_name"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
}

type skillMirrorDriftOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// HandleSkillMirrorDrift warns when skills/ SSOT edits are not mirrored yet.
// PostToolUse Write/Edit under skills/ only; warning-only (no block).
func HandleSkillMirrorDrift(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil {
		return writeSkillMirrorDriftApprove(out, "")
	}
	if len(strings.TrimSpace(string(data))) == 0 {
		return writeSkillMirrorDriftApprove(out, "")
	}

	var input skillMirrorDriftInput
	if err := json.Unmarshal(data, &input); err != nil {
		return writeSkillMirrorDriftApprove(out, "")
	}
	if input.ToolName != "Write" && input.ToolName != "Edit" && input.ToolName != "MultiEdit" {
		return writeSkillMirrorDriftApprove(out, "")
	}

	filePath := input.ToolInput.FilePath
	if filePath == "" || !isSkillsSSOTPath(filePath) {
		return writeSkillMirrorDriftApprove(out, "")
	}

	projectRoot := resolveProjectRoot()
	if projectRoot == "" {
		return writeSkillMirrorDriftApprove(out, "")
	}

	state, err := clientmirror.Scan(projectRoot, clientmirror.ScanOptions{})
	if err != nil {
		return writeSkillMirrorDriftApprove(out, "")
	}
	if state.Reason != clientmirror.ReasonDrift {
		return writeSkillMirrorDriftApprove(out, "")
	}

	msg := "Client Mirror drift detected after editing skills/ SSOT.\n\n" +
		"Run `./scripts/sync-skill-mirrors.sh` (or `harness mirror verify --json`) and sync the codex mirror before shipping.\n\n" +
		"This is a warning only; mirror-state.v1 reports drift status."
	return writeSkillMirrorDriftApprove(out, msg)
}

func isSkillsSSOTPath(filePath string) bool {
	clean := filepath.ToSlash(filepath.Clean(filePath))
	if strings.Contains(clean, "/skills-codex/") {
		return true
	}
	if strings.Contains(clean, "/skills/") || strings.HasPrefix(clean, "skills/") {
		return true
	}
	return false
}

func writeSkillMirrorDriftApprove(out io.Writer, message string) error {
	if message == "" {
		_, err := out.Write([]byte("{}\n"))
		return err
	}
	var payload skillMirrorDriftOutput
	payload.HookSpecificOutput.HookEventName = "PostToolUse"
	payload.HookSpecificOutput.AdditionalContext = message
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	_, err = out.Write(data)
	return err
}
