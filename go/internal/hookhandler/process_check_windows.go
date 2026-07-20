//go:build windows

package hookhandler

// isProcessAlive checks whether the process with the given PID is alive (Windows implementation).
//
// On Windows, sending signal 0 (the equivalent of Unix syscall.Kill(pid, 0)) is not
// supported. Actually sending os.Interrupt would terminate the process, so it is disallowed.
//
// Fail-safe policy: on Windows, do not remove the processing flag (i.e. treat it as alive).
// This matches the behavior of the bash version's `kill -0` not working under Git Bash either,
// and a leftover flag causes no real harm since it is overwritten at the next session start.
func isProcessAlive(_ int) bool {
	return true
}
