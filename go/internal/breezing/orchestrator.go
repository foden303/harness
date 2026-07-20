// Package breezing provides goroutine orchestration for Breezing mode.
//
// The behind-the-scenes infrastructure for when a Lead session spawns
// Workers/Reviewers in parallel:
//   - max-parallelism control (semaphore pattern)
//   - graceful shutdown via context.Context
//   - automatic task dependency resolution
//   - worktree lifecycle management
package breezing

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/foden303/harness/go/internal/lifecycle"
	"github.com/foden303/harness/go/internal/state"
)

// TaskStatus represents a task's progress within the orchestrator.
type TaskStatus string

const (
	TaskPending   TaskStatus = "pending"
	TaskRunning   TaskStatus = "running"
	TaskCompleted TaskStatus = "completed"
	TaskFailed    TaskStatus = "failed"
	TaskBlocked   TaskStatus = "blocked"
)

// Task represents a single task managed by the orchestrator.
type Task struct {
	// ID is the task identifier (e.g. "35.6.1").
	ID string
	// Description is a summary of the task.
	Description string
	// DependsOn is the list of task IDs this task depends on.
	DependsOn []string
	// AgentType is the kind of agent to spawn ("worker" / "reviewer").
	AgentType string
	// WorktreePath is the worktree path (when a worktree is used).
	WorktreePath string
}

// TaskResult represents the result when a task completes.
type TaskResult struct {
	// TaskID is the ID of the completed task.
	TaskID string
	// AgentID is the ID of the CC agent that ran it.
	AgentID string
	// CommitHash is the commit hash (on success).
	CommitHash string
	// Err is the error (on failure).
	Err error
	// Duration is the execution time.
	Duration time.Duration
}

// WorkerFunc is the callback the orchestrator invokes for each task.
// It must terminate promptly when the context is canceled.
type WorkerFunc func(ctx context.Context, task *Task) TaskResult

// ProgressFunc is the progress callback invoked when a task completes.
type ProgressFunc func(completed, total int, result TaskResult)

// Orchestrator manages parallel goroutine execution of Workers/Reviewers.
// It controls max parallelism with the semaphore pattern and achieves graceful shutdown via context.Context.
type Orchestrator struct {
	mu sync.Mutex

	// tasks are all managed tasks.
	tasks []*Task
	// status is the current state of each task.
	status map[string]TaskStatus
	// results are the results of completed tasks.
	results map[string]TaskResult

	// maxParallel is the maximum number of parallel executions.
	maxParallel int
	// tracker is agent lifecycle tracking.
	// workerFn is expected to call tracker.HandleStart/HandleStop.
	// The Orchestrator itself does not operate on tracker directly (delegated to workerFn).
	tracker *lifecycle.AgentTracker
	// store is the SQLite persistence store (nil allowed).
	// Expected to be used for state persistence inside workerFn.
	store *state.HarnessStore

	// workerFn is the execution function for each task.
	workerFn WorkerFunc
	// progressFn is the progress callback (nil allowed).
	progressFn ProgressFunc
}

// OrchestratorOption is a configuration option for the Orchestrator.
type OrchestratorOption func(*Orchestrator)

// WithMaxParallel sets the maximum parallelism.
// If it is 0 or less, the default (3) is used.
func WithMaxParallel(n int) OrchestratorOption {
	return func(o *Orchestrator) {
		if n > 0 {
			o.maxParallel = n
		}
	}
}

// WithTracker sets the AgentTracker.
func WithTracker(t *lifecycle.AgentTracker) OrchestratorOption {
	return func(o *Orchestrator) {
		o.tracker = t
	}
}

// WithStore sets the HarnessStore.
func WithStore(s *state.HarnessStore) OrchestratorOption {
	return func(o *Orchestrator) {
		o.store = s
	}
}

// WithProgressFunc sets the progress callback.
func WithProgressFunc(fn ProgressFunc) OrchestratorOption {
	return func(o *Orchestrator) {
		o.progressFn = fn
	}
}

// NewOrchestrator creates a new Orchestrator.
// workerFn is the execution function for each task (required).
func NewOrchestrator(workerFn WorkerFunc, opts ...OrchestratorOption) *Orchestrator {
	o := &Orchestrator{
		status:      make(map[string]TaskStatus),
		results:     make(map[string]TaskResult),
		maxParallel: 3,
		workerFn:    workerFn,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// AddTask adds a task to the orchestrator.
// Add all tasks before calling Run.
func (o *Orchestrator) AddTask(task *Task) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.tasks = append(o.tasks, task)
	o.status[task.ID] = TaskPending
}

// Run executes tasks in parallel according to their dependencies.
// It waits until all tasks complete (success or failure). Context cancellation triggers graceful shutdown.
// The returned []TaskResult is in completion order.
func (o *Orchestrator) Run(ctx context.Context) ([]TaskResult, error) {
	o.mu.Lock()
	total := len(o.tasks)
	if total == 0 {
		o.mu.Unlock()
		return nil, nil
	}
	o.mu.Unlock()

	// semaphore: buffered channel controlling max parallelism
	sem := make(chan struct{}, o.maxParallel)
	// resultCh: aggregates completion notifications
	resultCh := make(chan TaskResult, total)
	// wg: waits for all goroutines to finish
	var wg sync.WaitGroup

	// Periodically check for tasks whose dependencies are resolved and dispatch them
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	// dispatch loop
	go func() {
		ticker := time.NewTicker(50 * time.Millisecond)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				o.dispatchReady(ctx, sem, resultCh, &wg)

				// Exit once all tasks are completed or failed
				o.mu.Lock()
				allDone := o.allTerminated()
				o.mu.Unlock()
				if allDone {
					return
				}
			}
		}
	}()

	// Result aggregation loop
	var results []TaskResult
	completed := 0
	for completed < total {
		select {
		case result := <-resultCh:
			results = append(results, result)
			completed++
			if o.progressFn != nil {
				o.progressFn(completed, total, result)
			}
		case <-ctx.Done():
			// Canceled: wait for the results of all remaining tasks
			wg.Wait()
			// drain remaining results
			for len(resultCh) > 0 {
				result := <-resultCh
				results = append(results, result)
			}
			return results, ctx.Err()
		}
	}

	wg.Wait()
	return results, nil
}

// Status returns the current status of the given task.
func (o *Orchestrator) Status(taskID string) TaskStatus {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.status[taskID]
}

// Results returns the results of all completed tasks.
func (o *Orchestrator) Results() map[string]TaskResult {
	o.mu.Lock()
	defer o.mu.Unlock()
	res := make(map[string]TaskResult, len(o.results))
	for k, v := range o.results {
		res[k] = v
	}
	return res
}

// dispatchReady launches pending tasks whose dependencies are resolved in goroutines.
func (o *Orchestrator) dispatchReady(ctx context.Context, sem chan struct{}, resultCh chan<- TaskResult, wg *sync.WaitGroup) {
	o.mu.Lock()
	defer o.mu.Unlock()

	for _, task := range o.tasks {
		if o.status[task.ID] != TaskPending {
			continue
		}

		// Mark as blocked if a dependency has failed (checked before depsResolved)
		if o.depsFailed(task) {
			o.status[task.ID] = TaskBlocked
			resultCh <- TaskResult{
				TaskID: task.ID,
				Err:    fmt.Errorf("blocked: dependency failed"),
			}
			continue
		}

		if !o.depsResolved(task) {
			continue
		}

		// Try to acquire the semaphore (non-blocking)
		select {
		case sem <- struct{}{}:
		default:
			continue // parallelism limit reached
		}

		o.status[task.ID] = TaskRunning
		wg.Add(1)

		go func(t *Task) {
			defer wg.Done()
			defer func() { <-sem }() // release the semaphore

			start := time.Now()
			result := o.workerFn(ctx, t)
			result.Duration = time.Since(start)
			result.TaskID = t.ID

			o.mu.Lock()
			if result.Err != nil {
				o.status[t.ID] = TaskFailed
			} else {
				o.status[t.ID] = TaskCompleted
			}
			o.results[t.ID] = result
			o.mu.Unlock()

			resultCh <- result
		}(task)
	}
}

// depsResolved reports whether all dependency tasks are completed.
// Assumes the lock is already held.
func (o *Orchestrator) depsResolved(task *Task) bool {
	for _, depID := range task.DependsOn {
		if o.status[depID] != TaskCompleted {
			return false
		}
	}
	return true
}

// depsFailed reports whether any dependency task is failed/blocked.
// Assumes the lock is already held.
func (o *Orchestrator) depsFailed(task *Task) bool {
	for _, depID := range task.DependsOn {
		s := o.status[depID]
		if s == TaskFailed || s == TaskBlocked {
			return true
		}
	}
	return false
}

// allTerminated reports whether all tasks are in a terminal state (completed/failed/blocked).
// Assumes the lock is already held.
func (o *Orchestrator) allTerminated() bool {
	for _, task := range o.tasks {
		s := o.status[task.ID]
		if s != TaskCompleted && s != TaskFailed && s != TaskBlocked {
			return false
		}
	}
	return true
}
