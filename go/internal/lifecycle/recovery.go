// Package lifecycle provides the agent lifecycle state machine.
package lifecycle

import "fmt"

// RecoveryLevel represents a recovery stage.
// Corresponds to the 4 stages defined in SPEC.md §8.
type RecoveryLevel int

const (
	// SelfHeal is stage 1: self-repair. Error analysis -> auto-fix -> retry.
	SelfHeal RecoveryLevel = iota
	// PeerHeal is stage 2: peer repair. Delegate the task to another Worker.
	PeerHeal
	// LeadEscalation is stage 3: lead intervention. Escalate to the Lead session.
	LeadEscalation
	// Abort is stage 4: stop. Transition to the ABORTED state and notify the user.
	Abort
)

// String returns the string representation of a RecoveryLevel.
func (l RecoveryLevel) String() string {
	switch l {
	case SelfHeal:
		return "SelfHeal"
	case PeerHeal:
		return "PeerHeal"
	case LeadEscalation:
		return "LeadEscalation"
	case Abort:
		return "Abort"
	default:
		return fmt.Sprintf("RecoveryLevel(%d)", int(l))
	}
}

// RecoveryAction represents a recovery stage and the action to take.
type RecoveryAction struct {
	// Level is the current recovery stage.
	Level RecoveryLevel
	// Retry is true when the same task should be retried after self-repair.
	Retry bool
	// DelegateToWorker is true when the task should be delegated to another Worker.
	DelegateToWorker bool
	// EscalateToLead is true when the situation should be escalated to the Lead session.
	EscalateToLead bool
	// Stop is true when the process should stop in an unrecoverable state.
	Stop bool
	// Error is the error that triggered recovery (informational).
	Error error
}

// RecoveryManager manages the 4-stage recovery logic.
// It coordinates with the StateMachine to control transitions into the
// RECOVERING / ABORTED states.
type RecoveryManager struct {
	// sm is a reference to the lifecycle state machine.
	sm *StateMachine
	// attempts is the cumulative number of HandleFailure calls (0-based).
	attempts int
	// maxSelfHeal is the maximum number of self-repair attempts. Default 3.
	maxSelfHeal int
	// maxPeerHeal is the maximum number of peer-repair attempts. Default 1.
	maxPeerHeal int
}

// NewRecoveryManager creates a RecoveryManager with default settings.
// maxSelfHeal=3 and maxPeerHeal=1 are used as the initial values.
func NewRecoveryManager(sm *StateMachine) *RecoveryManager {
	return &RecoveryManager{
		sm:          sm,
		attempts:    0,
		maxSelfHeal: 3,
		maxPeerHeal: 1,
	}
}

// HandleFailure takes a failure and returns a recovery action based on the
// current attempt count.
// Stage decision rules (attempts is 0-based):
//
//	0th, 1st, 2nd (attempts < maxSelfHeal=3)         → SelfHeal (Retry=true)
//	3rd           (attempts < maxSelfHeal+maxPeerHeal=4)   → PeerHeal (DelegateToWorker=true)
//	4th           (attempts < maxSelfHeal+maxPeerHeal+1=5) → LeadEscalation (EscalateToLead=true)
//	5th and later (otherwise)                        → Abort (Stop=true)
//
// If the StateMachine is in the FAILED state, it transitions to RECOVERING.
// At the Abort stage it transitions RECOVERING → ABORTED.
func (rm *RecoveryManager) HandleFailure(err error) RecoveryAction {
	// If the StateMachine is FAILED, attempt a transition to RECOVERING.
	if rm.sm.Current() == StateFailed {
		_ = rm.sm.Transition(StateRecovering, fmt.Sprintf("recovery attempt %d: %v", rm.attempts+1, err))
	}

	action := rm.determineAction(err)
	rm.attempts++

	// At the Abort stage, transition the StateMachine to ABORTED.
	if action.Stop && rm.sm.Current() == StateRecovering {
		_ = rm.sm.Transition(StateAborted, fmt.Sprintf("all recovery attempts exhausted: %v", err))
	}

	return action
}

// determineAction is an internal method that decides the recovery action based
// on the current value of attempts.
// It is expected to be called before attempts is incremented.
func (rm *RecoveryManager) determineAction(err error) RecoveryAction {
	switch {
	case rm.attempts < rm.maxSelfHeal:
		// Stage 1: self-repair (SelfHeal)
		return RecoveryAction{
			Level: SelfHeal,
			Retry: true,
			Error: err,
		}
	case rm.attempts < rm.maxSelfHeal+rm.maxPeerHeal:
		// Stage 2: peer repair (PeerHeal)
		return RecoveryAction{
			Level:            PeerHeal,
			DelegateToWorker: true,
			Error:            err,
		}
	case rm.attempts < rm.maxSelfHeal+rm.maxPeerHeal+1:
		// Stage 3: lead intervention (LeadEscalation)
		return RecoveryAction{
			Level:          LeadEscalation,
			EscalateToLead: true,
			Error:          err,
		}
	default:
		// Stage 4: stop (Abort)
		return RecoveryAction{
			Level: Abort,
			Stop:  true,
			Error: err,
		}
	}
}

// Attempts returns the current number of recovery attempts.
func (rm *RecoveryManager) Attempts() int {
	return rm.attempts
}

// Reset resets the recovery attempt count to zero.
// Call this after a task completes successfully.
func (rm *RecoveryManager) Reset() {
	rm.attempts = 0
}
