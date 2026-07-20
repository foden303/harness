package breezing

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

// DependencyGraph manages dependencies between tasks and determines which tasks are runnable.
type DependencyGraph struct {
	mu    sync.RWMutex
	tasks map[string]*depNode
}

type depNode struct {
	task     *Task
	deps     []string // dependency task IDs
	status   TaskStatus
	resolved bool // all dependencies became completed
}

// NewDependencyGraph creates a new DependencyGraph.
func NewDependencyGraph() *DependencyGraph {
	return &DependencyGraph{
		tasks: make(map[string]*depNode),
	}
}

// Add adds a task to the dependency graph.
func (dg *DependencyGraph) Add(task *Task) {
	dg.mu.Lock()
	defer dg.mu.Unlock()
	dg.tasks[task.ID] = &depNode{
		task:   task,
		deps:   task.DependsOn,
		status: TaskPending,
	}
}

// Ready returns the list of runnable tasks whose dependencies are all resolved.
// The returned tasks are sorted by ID in ascending order.
func (dg *DependencyGraph) Ready() []*Task {
	dg.mu.RLock()
	defer dg.mu.RUnlock()

	var ready []*Task
	for _, node := range dg.tasks {
		if node.status != TaskPending {
			continue
		}
		if dg.allDepsCompleted(node) {
			ready = append(ready, node.task)
		}
	}

	sort.Slice(ready, func(i, j int) bool {
		return ready[i].ID < ready[j].ID
	})
	return ready
}

// MarkCompleted marks a task as completed and re-evaluates the dependency chain.
// The returned []*Task are the newly unblocked tasks.
func (dg *DependencyGraph) MarkCompleted(taskID string) []*Task {
	dg.mu.Lock()
	defer dg.mu.Unlock()

	if node, exists := dg.tasks[taskID]; exists {
		node.status = TaskCompleted
	}

	// Detect tasks that newly became ready
	var unblocked []*Task
	for _, node := range dg.tasks {
		if node.status != TaskPending {
			continue
		}
		if !node.resolved && dg.allDepsCompleted(node) {
			node.resolved = true
			unblocked = append(unblocked, node.task)
		}
	}
	return unblocked
}

// MarkFailed marks a task as failed.
// All tasks depending on this task become blocked.
func (dg *DependencyGraph) MarkFailed(taskID string) []string {
	dg.mu.Lock()
	defer dg.mu.Unlock()

	if node, exists := dg.tasks[taskID]; exists {
		node.status = TaskFailed
	}

	// Identify tasks that are blocked in a cascade
	var blocked []string
	changed := true
	for changed {
		changed = false
		for id, node := range dg.tasks {
			if node.status != TaskPending {
				continue
			}
			for _, depID := range node.deps {
				depNode := dg.tasks[depID]
				if depNode != nil && (depNode.status == TaskFailed || depNode.status == TaskBlocked) {
					node.status = TaskBlocked
					blocked = append(blocked, id)
					changed = true
					break
				}
			}
		}
	}
	return blocked
}

// DetectCycle detects whether the dependency graph has a circular reference.
// If there is a cycle, it returns a slice of the task IDs in the cycle.
func (dg *DependencyGraph) DetectCycle() []string {
	dg.mu.RLock()
	defer dg.mu.RUnlock()
	return dg.detectCycleLocked()
}

// detectCycleLocked is cycle detection that assumes the lock is already held.
func (dg *DependencyGraph) detectCycleLocked() []string {
	visited := make(map[string]bool)
	inStack := make(map[string]bool)
	var cyclePath []string

	var dfs func(id string) bool
	dfs = func(id string) bool {
		visited[id] = true
		inStack[id] = true

		node, exists := dg.tasks[id]
		if !exists {
			inStack[id] = false
			return false
		}

		for _, depID := range node.deps {
			if !visited[depID] {
				if dfs(depID) {
					cyclePath = append([]string{depID}, cyclePath...)
					return true
				}
			} else if inStack[depID] {
				cyclePath = append(cyclePath, depID)
				return true
			}
		}

		inStack[id] = false
		return false
	}

	for id := range dg.tasks {
		if !visited[id] {
			if dfs(id) {
				return cyclePath
			}
		}
	}
	return nil
}

// TopologicalOrder returns a topological sort order based on the dependencies.
// It returns an error if there is a cycle.
// It performs cycle detection + sorting within a single lock to prevent TOCTOU.
func (dg *DependencyGraph) TopologicalOrder() ([]string, error) {
	dg.mu.RLock()
	defer dg.mu.RUnlock()

	// inline cycle detection
	if cycle := dg.detectCycleLocked(); len(cycle) > 0 {
		return nil, fmt.Errorf("circular dependency detected: %s", strings.Join(cycle, " → "))
	}

	inDegree := make(map[string]int)
	for id := range dg.tasks {
		inDegree[id] = 0
	}
	for _, node := range dg.tasks {
		for _, depID := range node.deps {
			if _, exists := dg.tasks[depID]; exists {
				inDegree[node.task.ID]++
			}
		}
	}

	// Kahn's algorithm
	var queue []string
	for id, deg := range inDegree {
		if deg == 0 {
			queue = append(queue, id)
		}
	}
	sort.Strings(queue)

	var order []string
	for len(queue) > 0 {
		id := queue[0]
		queue = queue[1:]
		order = append(order, id)

		// Decrement the in-degree of tasks depending on this task
		for othID, node := range dg.tasks {
			for _, depID := range node.deps {
				if depID == id {
					inDegree[othID]--
					if inDegree[othID] == 0 {
						queue = append(queue, othID)
						sort.Strings(queue) // stable sort
					}
				}
			}
		}
	}

	return order, nil
}

// allDepsCompleted reports whether all dependencies of the given node are completed.
// Assumes the lock is already held.
func (dg *DependencyGraph) allDepsCompleted(node *depNode) bool {
	for _, depID := range node.deps {
		dep, exists := dg.tasks[depID]
		if !exists {
			// External dependencies (not present in the graph) are treated as completed
			continue
		}
		if dep.status != TaskCompleted {
			return false
		}
	}
	return true
}

// ============================================================
// File-Lock Claiming
// ============================================================

// FileLock manages file-based locks.
// Used by a Worker to claim exclusive modification rights over a specific file.
type FileLock struct {
	mu      sync.Mutex
	lockDir string
	locks   map[string]string // filePath → ownerID
	now     func() time.Time
}

// NewFileLock creates a new FileLock.
// lockDir is the path to the .harness-locks/ directory.
func NewFileLock(lockDir string) *FileLock {
	return &FileLock{
		lockDir: lockDir,
		locks:   make(map[string]string),
		now:     time.Now,
	}
}

// Claim acquires a lock on a file.
// Returns an error if another owner already holds the lock.
func (fl *FileLock) Claim(filePath, ownerID string) error {
	filePath = filepath.Clean(filePath)
	fl.mu.Lock()
	defer fl.mu.Unlock()

	// Fail immediately if another owner holds it in memory
	if existing, exists := fl.locks[filePath]; exists && existing != ownerID {
		return fmt.Errorf("file %q is locked by %q", filePath, existing)
	}

	// Atomic exclusion on the filesystem (O_CREATE|O_EXCL)
	lockFile := fl.lockFilePath(filePath)
	if err := os.MkdirAll(filepath.Dir(lockFile), 0o755); err != nil {
		return fmt.Errorf("create lock dir: %w", err)
	}
	content := fmt.Sprintf("%s\n%s\n", ownerID, fl.now().UTC().Format(time.RFC3339))
	f, err := os.OpenFile(lockFile, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
	if err != nil {
		if os.IsExist(err) {
			// Lock file already exists — check whether it is a re-claim by the same owner
			existing, readErr := os.ReadFile(lockFile)
			if readErr == nil {
				lines := strings.SplitN(string(existing), "\n", 2)
				if len(lines) > 0 && strings.TrimSpace(lines[0]) == ownerID {
					// Same owner — update the lock file and allow the re-claim
					_ = os.WriteFile(lockFile, []byte(content), 0o644)
					fl.locks[filePath] = ownerID
					return nil
				}
			}
			return fmt.Errorf("file %q is locked by another process: %s", filePath, strings.TrimSpace(string(existing)))
		}
		return fmt.Errorf("create lock file: %w", err)
	}
	if _, err := f.WriteString(content); err != nil {
		f.Close()
		os.Remove(lockFile) // rollback: remove the incomplete lock file
		return fmt.Errorf("write lock file: %w", err)
	}
	if err := f.Close(); err != nil {
		os.Remove(lockFile)
		return fmt.Errorf("close lock file: %w", err)
	}

	// Update the memory state after the file lock succeeds (unreachable on failure)
	fl.locks[filePath] = ownerID
	return nil
}

// Release releases the lock on a file.
// It verifies the owner both in memory and on disk, returning an error if they do not match.
func (fl *FileLock) Release(filePath, ownerID string) error {
	filePath = filepath.Clean(filePath)
	fl.mu.Lock()
	defer fl.mu.Unlock()

	// Check the owner in memory
	if existing, exists := fl.locks[filePath]; exists && existing != ownerID {
		return fmt.Errorf("file %q is locked by %q, not %q", filePath, existing, ownerID)
	}

	// Also verify the owner of the lock file on disk (cross-process safety)
	lockFile := fl.lockFilePath(filePath)
	if data, err := os.ReadFile(lockFile); err == nil {
		lines := strings.SplitN(string(data), "\n", 2)
		if len(lines) > 0 {
			diskOwner := strings.TrimSpace(lines[0])
			if diskOwner != ownerID {
				return fmt.Errorf("file %q is locked on disk by %q, not %q", filePath, diskOwner, ownerID)
			}
		}
	}

	delete(fl.locks, filePath)
	_ = os.Remove(lockFile)

	return nil
}

// ReleaseAll releases all locks held by the given owner.
// It releases only what is owned in memory and also verifies the owner on disk.
func (fl *FileLock) ReleaseAll(ownerID string) {
	fl.mu.Lock()
	defer fl.mu.Unlock()

	for filePath, owner := range fl.locks {
		if owner == ownerID {
			lockFile := fl.lockFilePath(filePath)
			// Verify the owner on disk before deleting
			if data, err := os.ReadFile(lockFile); err == nil {
				lines := strings.SplitN(string(data), "\n", 2)
				if len(lines) > 0 && strings.TrimSpace(lines[0]) != ownerID {
					continue // owner on disk differs — do not delete
				}
			}
			delete(fl.locks, filePath)
			_ = os.Remove(lockFile)
		}
	}
}

// Owner returns the lock owner of a file. Empty string if not locked.
func (fl *FileLock) Owner(filePath string) string {
	filePath = filepath.Clean(filePath)
	fl.mu.Lock()
	defer fl.mu.Unlock()
	return fl.locks[filePath]
}

// lockFilePath returns the path of the lock file.
func (fl *FileLock) lockFilePath(filePath string) string {
	// Convert the file path into a flat filename
	safe := strings.NewReplacer("/", "__", "\\", "__", ":", "_").Replace(filePath)
	return filepath.Join(fl.lockDir, safe+".lock")
}
