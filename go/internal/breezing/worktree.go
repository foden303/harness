package breezing

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/foden303/harness/go/internal/gitport"
)

// HarnessWorktreesRoot is the single root for Harness-managed parallel task worktrees.
// scripts/spawn-parallel.sh and WorktreeManager both use this directory.
// .claude/worktrees/ is a separate CC live-agent root and must not be mixed with this path.
const HarnessWorktreesRoot = ".harness-worktrees"

// ParallelWorktreePath returns the spawn-parallel.sh worktree path for taskID.
func ParallelWorktreePath(projectRoot, taskID string) string {
	return filepath.Join(projectRoot, HarnessWorktreesRoot, "task-"+taskID)
}

// ManagerWorktreePath returns the WorktreeManager worktree path for taskID.
func ManagerWorktreePath(projectRoot, taskID string) string {
	return filepath.Join(projectRoot, HarnessWorktreesRoot, sanitizeBranch(taskID))
}

// WorktreeManager manages creation and cleanup of git worktrees.
// It tracks the worktree lifecycle in coordination with CC's WorktreeCreate/Remove hooks.
type WorktreeManager struct {
	mu sync.Mutex
	// projectRoot is the root path of the main repository.
	projectRoot string
	// worktrees is the list of currently managed worktrees (path → info).
	worktrees map[string]*WorktreeInfo
	// staleTimeout is the duration after which a worktree is considered stale.
	staleTimeout time.Duration
	// now is a time function for test substitution.
	now func() time.Time
}

// WorktreeInfo is tracking information for an individual worktree.
type WorktreeInfo struct {
	// Path is the worktree's filesystem path.
	Path string
	// Branch is the worktree's branch name.
	Branch string
	// TaskID is the task ID assigned to the worktree.
	TaskID string
	// AgentID is the ID of the CC agent using the worktree.
	AgentID string
	// CreatedAt is the creation time.
	CreatedAt time.Time
	// Active reports whether the worktree is in use.
	Active bool
}

// NewWorktreeManager returns a new WorktreeManager.
func NewWorktreeManager(projectRoot string) *WorktreeManager {
	return &WorktreeManager{
		projectRoot:  projectRoot,
		worktrees:    make(map[string]*WorktreeInfo),
		staleTimeout: 24 * time.Hour,
		now:          time.Now,
	}
}

// Create creates a new worktree.
// If branchName is empty, it is auto-generated from taskID.
// Returns the path of the created worktree.
func (wm *WorktreeManager) Create(taskID, branchName string) (string, error) {
	wm.mu.Lock()
	defer wm.mu.Unlock()

	if branchName == "" {
		branchName = fmt.Sprintf("harness/worker/%s", sanitizeBranch(taskID))
	}

	// Determine the worktree path
	worktreeDir := ManagerWorktreePath(wm.projectRoot, taskID)

	// Reuse if it already exists
	if info, exists := wm.worktrees[worktreeDir]; exists && info.Active {
		return worktreeDir, nil
	}

	// git worktree add
	if err := wm.gitWorktreeAdd(worktreeDir, branchName); err != nil {
		return "", fmt.Errorf("worktree create: %w", err)
	}

	wm.worktrees[worktreeDir] = &WorktreeInfo{
		Path:      worktreeDir,
		Branch:    branchName,
		TaskID:    taskID,
		CreatedAt: wm.now(),
		Active:    true,
	}

	return worktreeDir, nil
}

// Remove deletes a worktree.
// If force is true, it deletes even when there are uncommitted changes.
func (wm *WorktreeManager) Remove(worktreePath string, force bool) error {
	wm.mu.Lock()
	defer wm.mu.Unlock()

	args := []string{"worktree", "remove", worktreePath}
	if force {
		args = append(args, "--force")
	}

	if out, err := gitport.CombinedOutput(wm.projectRoot, args...); err != nil {
		return fmt.Errorf("worktree remove: %s: %w", strings.TrimSpace(out), err)
	}

	// Delete the branch
	if info, exists := wm.worktrees[worktreePath]; exists {
		wm.deleteBranch(info.Branch)
		delete(wm.worktrees, worktreePath)
	}

	return nil
}

// AssignAgent associates a CC agent ID with a worktree.
func (wm *WorktreeManager) AssignAgent(worktreePath, agentID string) {
	wm.mu.Lock()
	defer wm.mu.Unlock()
	if info, exists := wm.worktrees[worktreePath]; exists {
		info.AgentID = agentID
	}
}

// CleanupStale deletes inactive worktrees that have exceeded staleTimeout.
// Returns the list of paths of the deleted worktrees.
func (wm *WorktreeManager) CleanupStale() []string {
	wm.mu.Lock()
	stale := make([]string, 0)
	now := wm.now()
	for path, info := range wm.worktrees {
		if !info.Active && now.Sub(info.CreatedAt) > wm.staleTimeout {
			stale = append(stale, path)
		}
	}
	wm.mu.Unlock()

	var cleaned []string
	for _, path := range stale {
		if err := wm.Remove(path, true); err != nil {
			fmt.Fprintf(os.Stderr, "worktree cleanup: %s: %v\n", path, err)
		} else {
			cleaned = append(cleaned, path)
		}
	}
	return cleaned
}

// MarkInactive marks a worktree as inactive (when the agent stops).
func (wm *WorktreeManager) MarkInactive(worktreePath string) {
	wm.mu.Lock()
	defer wm.mu.Unlock()
	if info, exists := wm.worktrees[worktreePath]; exists {
		info.Active = false
	}
}

// List returns information on all managed worktrees.
func (wm *WorktreeManager) List() []*WorktreeInfo {
	wm.mu.Lock()
	defer wm.mu.Unlock()
	result := make([]*WorktreeInfo, 0, len(wm.worktrees))
	for _, info := range wm.worktrees {
		cp := *info
		result = append(result, &cp)
	}
	return result
}

// HandleWorktreeCreate handles CC's WorktreeCreate hook event.
// It extracts path information from stdin's tool_input and starts tracking.
func (wm *WorktreeManager) HandleWorktreeCreate(worktreePath, branch, agentID string) {
	wm.mu.Lock()
	defer wm.mu.Unlock()

	wm.worktrees[worktreePath] = &WorktreeInfo{
		Path:      worktreePath,
		Branch:    branch,
		AgentID:   agentID,
		CreatedAt: wm.now(),
		Active:    true,
	}
}

// HandleWorktreeRemove handles CC's WorktreeRemove hook event.
func (wm *WorktreeManager) HandleWorktreeRemove(worktreePath string) {
	wm.mu.Lock()
	defer wm.mu.Unlock()
	delete(wm.worktrees, worktreePath)
}

// gitWorktreeAdd runs git worktree add.
func (wm *WorktreeManager) gitWorktreeAdd(worktreeDir, branchName string) error {
	// Delete the directory if it already exists
	if _, err := os.Stat(worktreeDir); err == nil {
		_ = gitport.Run(wm.projectRoot, "worktree", "remove", worktreeDir, "--force")
	}

	if out, err := gitport.CombinedOutput(wm.projectRoot, "worktree", "add", "-b", branchName, worktreeDir, "HEAD"); err != nil {
		return fmt.Errorf("%s: %w", strings.TrimSpace(out), err)
	}
	return nil
}

// deleteBranch deletes the branch created for the worktree.
func (wm *WorktreeManager) deleteBranch(branch string) {
	if branch == "" {
		return
	}
	_ = gitport.Run(wm.projectRoot, "branch", "-D", branch)
}

// sanitizeBranch sanitizes a task ID so it can be used as a branch name.
func sanitizeBranch(s string) string {
	r := strings.NewReplacer(
		" ", "-",
		"/", "-",
		".", "-",
		":", "-",
	)
	return r.Replace(s)
}
