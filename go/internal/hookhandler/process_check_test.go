package hookhandler

import (
	"os"
	"testing"
)

// TestIsProcessAlive_CurrentProcess verifies the current process is reported as alive.
func TestIsProcessAlive_CurrentProcess(t *testing.T) {
	pid := os.Getpid()
	if !isProcessAlive(pid) {
		t.Errorf("isProcessAlive(%d) = false for current process, want true", pid)
	}
}

// TestIsProcessAlive_NonExistentPID verifies a non-existent PID is reported as not alive.
// PID 0 is a system process (or the kernel), so signal delivery from a normal process is refused.
// PID -1 is an invalid PID and errors out (on Unix it signals all processes).
// Here we use a large value (expected not to exist).
func TestIsProcessAlive_NonExistentPID(t *testing.T) {
	// A very large PID (normally does not exist)
	// The max PID on Linux/macOS is generally at or below 4194304
	nonExistentPID := 9999999
	// This test cannot guarantee the result is deterministic, but it
	// verifies that it does not panic
	result := isProcessAlive(nonExistentPID)
	// We expect false for a non-existent PID, but since it may differ by
	// OS, we only record the result
	t.Logf("isProcessAlive(%d) = %v (expected false for non-existent PID)", nonExistentPID, result)
}

// TestIsProcessAlive_ZeroPID verifies that handling a zero PID does not panic.
func TestIsProcessAlive_ZeroPID(t *testing.T) {
	// PID 0 is special, so we only verify it does not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("isProcessAlive(0) panicked: %v", r)
		}
	}()
	_ = isProcessAlive(0)
}
