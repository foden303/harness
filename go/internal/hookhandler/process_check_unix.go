//go:build !windows

package hookhandler

import "syscall"

// isProcessAlive checks whether the process with the given PID is alive (Unix implementation).
// uses the kill -0 equivalent (sending signal 0) to check process existence.
// returns true when the process exists and a signal can be sent.
func isProcessAlive(pid int) bool {
	return syscall.Kill(pid, 0) == nil
}
