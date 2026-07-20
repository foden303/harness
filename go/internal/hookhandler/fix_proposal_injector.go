package hookhandler

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// FixProposalInjectorHandler is the UserPromptSubmit hook handler.
// It reads pending-fix-proposals.jsonl and notifies the user of unshown proposals.
// It interprets "approve fix" / "reject fix" commands and applies them to Plans.md.
//
// shell version: scripts/hook-handlers/fix-proposal-injector.sh
type FixProposalInjectorHandler struct {
	// ProjectRoot is the project root path. If empty, cwd is used.
	ProjectRoot string
	// PlansPath is the Plans.md path. If empty, ProjectRoot/Plans.md is used.
	PlansPath string
}

// fixProposalInjectorInput is the stdin JSON for the UserPromptSubmit hook.
type fixProposalInjectorInput struct {
	Prompt string `json:"prompt"`
}

// fixProposalInjectorOutput is the UserPromptSubmit hook response.
// It notifies the user via systemMessage.
type fixProposalInjectorOutput struct {
	SystemMessage string `json:"systemMessage,omitempty"`
}

const (
	pendingFixProposalsFile = "pending-fix-proposals.jsonl"
	fixProposalMaxLines     = 500
)

// Handle reads the UserPromptSubmit payload from stdin and
// notifies/processes fix proposals.
func (h *FixProposalInjectorHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)
	if len(data) == 0 {
		return nil
	}

	var inp fixProposalInjectorInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return nil
	}

	projectRoot := h.resolveProjectRoot()
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	proposalsFile := filepath.Join(stateDir, pendingFixProposalsFile)

	// Skip if the proposals file does not exist.
	if _, err := os.Stat(proposalsFile); os.IsNotExist(err) {
		return nil
	}

	// symlink check (isSymlink is defined in notification_handler.go)
	if hasFixSymlinkComponent(stateDir, projectRoot) || isSymlink(proposalsFile) {
		return writeFixProposalJSON(w, fixProposalInjectorOutput{
			SystemMessage: "Warning: fix proposal state path is a symlink; processing stopped.",
		})
	}

	plansPath := h.resolvePlansPath(projectRoot)
	if _, err := os.Stat(plansPath); err == nil {
		if hasFixSymlinkComponent(plansPath, projectRoot) {
			return writeFixProposalJSON(w, fixProposalInjectorOutput{
				SystemMessage: "Warning: Plans.md path is a symlink; fix proposal cannot be applied.",
			})
		}
	}

	// Parse the prompt to determine the action.
	firstLine := strings.TrimSpace(strings.SplitN(inp.Prompt, "\n", 2)[0])
	lower := strings.ToLower(firstLine)
	action, targetID := parseFixProposalAction(lower, firstLine)

	// Load the pending proposals.
	proposals, err := loadPendingFixProposals(proposalsFile)
	if err != nil || len(proposals) == 0 {
		return nil
	}

	pendingCount := len(proposals)

	// Error if there is an action but no target specified and multiple proposals exist.
	if action != "" && targetID == "" && pendingCount != 1 {
		return writeFixProposalJSON(w, fixProposalInjectorOutput{
			SystemMessage: fmt.Sprintf(
				"Warning: %d pending fix proposals exist. Use approve fix <task_id> or reject fix <task_id> to specify the target.",
				pendingCount,
			),
		})
	}

	// Select the target proposal.
	proposal, found := selectFixProposal(proposals, targetID)
	if !found {
		if targetID != "" {
			return writeFixProposalJSON(w, fixProposalInjectorOutput{
				SystemMessage: fmt.Sprintf("Warning: specified fix proposal not found: %s", targetID),
			})
		}
		return nil
	}

	// approve handling
	if action == "approve" {
		applyResult := applyFixProposalToPlans(plansPath, proposal)
		if applyResult == "applied" || applyResult == "already_present" {
			if err := consumeFixProposal(proposalsFile, proposal.SourceTaskID); err != nil {
				_ = err
			}
			return writeFixProposalJSON(w, fixProposalInjectorOutput{
				SystemMessage: fmt.Sprintf("Applied fix proposal: %s\nContent: %s", proposal.FixTaskID, proposal.ProposalSubject),
			})
		} else if applyResult == "plans_missing" {
			return writeFixProposalJSON(w, fixProposalInjectorOutput{
				SystemMessage: "Warning: fix proposal could not be applied because Plans.md was not found.",
			})
		} else {
			return writeFixProposalJSON(w, fixProposalInjectorOutput{
				SystemMessage: fmt.Sprintf("Warning: failed to apply fix proposal. Target task %s was not found in Plans.md.", proposal.SourceTaskID),
			})
		}
	}

	// reject handling
	if action == "reject" {
		_ = consumeFixProposal(proposalsFile, proposal.SourceTaskID)
		return writeFixProposalJSON(w, fixProposalInjectorOutput{
			SystemMessage: fmt.Sprintf("Rejected fix proposal: %s", proposal.FixTaskID),
		})
	}

	// No action -> show a reminder.
	reminder := buildFixProposalReminder(proposal, pendingCount)
	return writeFixProposalJSON(w, fixProposalInjectorOutput{SystemMessage: reminder})
}

// resolveProjectRoot resolves the project root.
func (h *FixProposalInjectorHandler) resolveProjectRoot() string {
	if h.ProjectRoot != "" {
		return h.ProjectRoot
	}
	wd, _ := os.Getwd()
	return wd
}

// resolvePlansPath resolves the Plans.md path.
// If PlansPath is explicitly set it is used; otherwise the path is resolved
// taking the config file's plansDirectory into account.
// Even when Plans.md does not exist, the full path is returned (so that apply
// can return plans_missing).
func (h *FixProposalInjectorHandler) resolvePlansPath(projectRoot string) string {
	if h.PlansPath != "" {
		return h.PlansPath
	}
	// Get the path of an existing Plans.md.
	if p := resolvePlansPath(projectRoot); p != "" {
		return p
	}
	// If none exists, return the default path taking config plansDirectory into account.
	plansDir := readPlansDirectoryFromConfig(projectRoot)
	if plansDir != "" {
		return filepath.Join(projectRoot, plansDir, "Plans.md")
	}
	return filepath.Join(projectRoot, "Plans.md")
}

// parseFixProposalAction parses the action and target ID from the prompt line.
func parseFixProposalAction(lower, original string) (action, targetID string) {
	switch {
	case lower == "approve fix" || strings.HasPrefix(lower, "approve fix "):
		action = "approve"
		re := regexp.MustCompile(`(?i)^approve fix\s*(.*)$`)
		if m := re.FindStringSubmatch(original); m != nil {
			targetID = strings.TrimSpace(m[1])
		}
	case lower == "reject fix" || strings.HasPrefix(lower, "reject fix "):
		action = "reject"
		re := regexp.MustCompile(`(?i)^reject fix\s*(.*)$`)
		if m := re.FindStringSubmatch(original); m != nil {
			targetID = strings.TrimSpace(m[1])
		}
	case lower == "yes" || lower == "approve":
		action = "approve"
	case lower == "no" || lower == "reject":
		action = "reject"
	}
	return action, targetID
}

// loadPendingFixProposals reads fixProposals with status=pending from the JSONL file.
// The fixProposal type is defined in task_completed_escalation.go.
func loadPendingFixProposals(path string) ([]fixProposal, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var result []fixProposal
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var p fixProposal
		if err := json.Unmarshal([]byte(line), &p); err != nil {
			continue
		}
		if p.Status == "" || p.Status == "pending" {
			result = append(result, p)
		}
	}
	return result, scanner.Err()
}

// selectFixProposal returns the fixProposal matching selector from proposals.
// If selector is empty, the first fixProposal is returned.
func selectFixProposal(proposals []fixProposal, selector string) (fixProposal, bool) {
	if len(proposals) == 0 {
		return fixProposal{}, false
	}
	if selector == "" {
		return proposals[0], true
	}
	for _, p := range proposals {
		if p.SourceTaskID == selector || p.FixTaskID == selector {
			return p, true
		}
	}
	return fixProposal{}, false
}

// consumeFixProposal removes the line with the given source_task_id from the JSONL.
func consumeFixProposal(path, sourceTaskID string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}

	var remaining []fixProposal
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var p fixProposal
		if err := json.Unmarshal([]byte(line), &p); err != nil {
			continue
		}
		if p.SourceTaskID == sourceTaskID {
			continue // skip the deletion target
		}
		remaining = append(remaining, p)
	}
	f.Close()
	if err := scanner.Err(); err != nil {
		return err
	}

	// Rewrite the file (JSONL rotation: if over 500 lines, truncate from the head).
	if len(remaining) > fixProposalMaxLines {
		remaining = remaining[len(remaining)-fixProposalMaxLines:]
	}

	tmp := path + ".tmp"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	for _, p := range remaining {
		line, _ := json.Marshal(p)
		_, _ = fmt.Fprintf(out, "%s\n", line)
	}
	out.Close()
	return os.Rename(tmp, path)
}

// applyFixProposalToPlans inserts the proposal immediately after the source_task_id
// line in Plans.md.
// Return values: "applied" / "already_present" / "plans_missing" / "source_not_found"
func applyFixProposalToPlans(plansPath string, proposal fixProposal) string {
	rawData, err := os.ReadFile(plansPath)
	if err != nil {
		return "plans_missing"
	}

	text := string(rawData)

	// Check whether fix_task_id already exists.
	fixPattern := regexp.MustCompile(`(?m)^\|\s*` + regexp.QuoteMeta(proposal.FixTaskID) + `\s*\|`)
	if fixPattern.MatchString(text) {
		return "already_present"
	}

	// Find the source_task_id line and insert immediately after it.
	sourcePattern := regexp.MustCompile(`(?m)^\|\s*` + regexp.QuoteMeta(proposal.SourceTaskID) + `\s*\|`)

	subject := strings.ReplaceAll(proposal.ProposalSubject, "|", "/")
	dod := strings.ReplaceAll(proposal.DoD, "|", "/")
	depends := strings.ReplaceAll(proposal.Depends, "|", "/")
	newRow := fmt.Sprintf("| %s | %s | %s | %s | cc:TODO |", proposal.FixTaskID, subject, dod, depends)

	lines := strings.Split(text, "\n")
	inserted := false
	result := make([]string, 0, len(lines)+1)
	for _, line := range lines {
		result = append(result, line)
		if !inserted && sourcePattern.MatchString(line) {
			result = append(result, newRow)
			inserted = true
		}
	}

	if !inserted {
		return "source_not_found"
	}

	content := strings.Join(result, "\n")
	if !strings.HasSuffix(content, "\n") {
		content += "\n"
	}

	tmp := plansPath + ".tmp"
	if err := os.WriteFile(tmp, []byte(content), 0644); err != nil {
		return "source_not_found"
	}
	if err := os.Rename(tmp, plansPath); err != nil {
		_ = os.Remove(tmp)
		return "source_not_found"
	}
	return "applied"
}

// buildFixProposalReminder builds the reminder message.
func buildFixProposalReminder(proposal fixProposal, pendingCount int) string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("[FIX PROPOSAL] Pending fix proposals exist (%d)\n", pendingCount))
	sb.WriteString(fmt.Sprintf("Target: %s — %s\n", proposal.FixTaskID, proposal.ProposalSubject))
	sb.WriteString(fmt.Sprintf("Failure category: %s\n", proposal.FailureCategory))
	sb.WriteString(fmt.Sprintf("DoD: %s\n", proposal.DoD))
	if proposal.RecommendedAction != "" {
		sb.WriteString(fmt.Sprintf("Recommended action: %s\n", proposal.RecommendedAction))
	}
	sb.WriteString(fmt.Sprintf("Approve: approve fix %s\n", proposal.SourceTaskID))
	sb.WriteString(fmt.Sprintf("Reject: reject fix %s", proposal.SourceTaskID))
	return sb.String()
}

// hasFixSymlinkComponent checks whether the path contains a symlink component
// within the project root.
// isSymlink is defined in userprompt_track_command.go (notification_handler.go).
func hasFixSymlinkComponent(path, root string) bool {
	path = strings.TrimSuffix(path, "/")
	root = strings.TrimSuffix(root, "/")

	for path != "" && path != root {
		if isSymlink(path) {
			return true
		}
		parent := filepath.Dir(path)
		if parent == path {
			break
		}
		path = parent
	}
	return isSymlink(root)
}

// writeFixProposalJSON writes v to w as JSON.
func writeFixProposalJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
