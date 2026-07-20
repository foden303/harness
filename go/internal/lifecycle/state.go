// Package lifecycle provides the agent lifecycle state machine.
//
// It declaratively implements all transition rules defined in SPEC.md §8.
// Happy path: SPAWNING → RUNNING → REVIEWING → APPROVED → COMMITTED
// Abnormal paths: including FAILED / CANCELLED / STALE / RECOVERING / ABORTED.
package lifecycle

import (
	"fmt"
	"sync"
)

// AgentState is a string type representing an agent's state.
type AgentState string

const (
	// StateSpawning indicates the agent is starting up.
	StateSpawning AgentState = "SPAWNING"
	// StateRunning indicates the agent is executing a task.
	StateRunning AgentState = "RUNNING"
	// StateReviewing indicates the review phase is in progress.
	StateReviewing AgentState = "REVIEWING"
	// StateApproved indicates the review was approved.
	StateApproved AgentState = "APPROVED"
	// StateCommitted is a terminal state indicating the commit is complete.
	StateCommitted AgentState = "COMMITTED"
	// StateFailed indicates a failure due to an error.
	StateFailed AgentState = "FAILED"
	// StateCancelled is a terminal state indicating a stop due to user interruption.
	StateCancelled AgentState = "CANCELLED"
	// StateStale indicates an automatic stop after exceeding 24h.
	StateStale AgentState = "STALE"
	// StateRecovering indicates recovery is in progress.
	StateRecovering AgentState = "RECOVERING"
	// StateAborted is a terminal state requiring human intervention after recovery failed.
	StateAborted AgentState = "ABORTED"
)

// terminalStates is the set of non-transitionable terminal states.
var terminalStates = map[AgentState]struct{}{
	StateCommitted: {},
	StateAborted:   {},
	StateCancelled: {},
}

// IsTerminal returns whether the given state is a terminal state.
// COMMITTED / ABORTED / CANCELLED are terminal states.
func IsTerminal(state AgentState) bool {
	_, ok := terminalStates[state]
	return ok
}

// transitionKey is the (From, To) pair used as the transition table key.
type transitionKey struct {
	From AgentState
	To   AgentState
}

// validTransitions declaratively defines all permitted transition rules.
// It covers the happy path and abnormal paths of SPEC.md §8.
var validTransitions = map[transitionKey]struct{}{
	// Happy path
	{StateSpawning, StateRunning}:   {}, // startup succeeded
	{StateRunning, StateReviewing}:  {}, // execution complete → review
	{StateReviewing, StateApproved}: {}, // review approved
	{StateApproved, StateCommitted}: {}, // commit complete

	// Abnormal: FAILED
	{StateSpawning, StateFailed}:  {}, // startup failed
	{StateRunning, StateFailed}:   {}, // error during execution / retry count of 3 exceeded
	{StateReviewing, StateFailed}: {}, // error during review

	// Abnormal: CANCELLED
	{StateRunning, StateCancelled}:   {}, // user interrupt (Ctrl+C)
	{StateReviewing, StateCancelled}: {}, // user interrupt

	// Abnormal: STALE (exceeded 24h)
	{StateRunning, StateStale}:   {}, // exceeded 24h while running
	{StateReviewing, StateStale}: {}, // exceeded 24h while reviewing

	// Abnormal: RECOVERING
	{StateFailed, StateRecovering}: {}, // recovery started

	// Abnormal: recovery result
	{StateRecovering, StateRunning}: {}, // recovery succeeded → re-run
	{StateRecovering, StateAborted}: {}, // recovery failed → human intervention required
}

// Transition records a single state transition.
type Transition struct {
	// From is the source state.
	From AgentState
	// To is the destination state.
	To AgentState
	// Trigger describes the event that caused the transition.
	Trigger string
}

// StateMachine is the agent lifecycle state machine.
// Goroutine-safe.
type StateMachine struct {
	mu      sync.RWMutex
	current AgentState
	history []Transition
}

// NewStateMachine returns a new StateMachine starting in the SPAWNING state.
func NewStateMachine() *StateMachine {
	return &StateMachine{
		current: StateSpawning,
		history: make([]Transition, 0),
	}
}

// Current returns the current state.
func (sm *StateMachine) Current() AgentState {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.current
}

// CanTransition returns whether a transition from the current state to the given
// state is permitted.
func (sm *StateMachine) CanTransition(to AgentState) bool {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.canTransitionLocked(to)
}

// canTransitionLocked is an internal method that determines whether a transition
// is possible, assuming the lock is already held.
func (sm *StateMachine) canTransitionLocked(to AgentState) bool {
	key := transitionKey{From: sm.current, To: to}
	_, ok := validTransitions[key]
	return ok
}

// Transition moves from the current state to to.
// It returns an error if the transition is not permitted.
// trigger takes a description of the event that caused the transition (for logging/debugging).
func (sm *StateMachine) Transition(to AgentState, trigger string) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if !sm.canTransitionLocked(to) {
		return fmt.Errorf(
			"lifecycle: invalid transition %s → %s (trigger: %q)",
			sm.current, to, trigger,
		)
	}

	t := Transition{
		From:    sm.current,
		To:      to,
		Trigger: trigger,
	}
	sm.history = append(sm.history, t)
	sm.current = to
	return nil
}

// History returns a copy of the recorded transition history.
// Modifying the returned slice does not affect internal state.
func (sm *StateMachine) History() []Transition {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	result := make([]Transition, len(sm.history))
	copy(result, sm.history)
	return result
}
