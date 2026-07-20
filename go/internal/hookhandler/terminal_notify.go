package hookhandler

// terminal_notify.go
// Shared helper that builds the `terminalSequence` field of the CC 2.1.141+ hook JSON output.
// Opt-in via the HARNESS_TERMINAL_NOTIFY env.
//
// shell reference implementation: scripts/lib/terminal-notify.sh

import (
	"os"
	"strings"
)

// terminalNotifyMode is the result of interpreting the HARNESS_TERMINAL_NOTIFY env.
type terminalNotifyMode int

const (
	notifyOff terminalNotifyMode = iota
	notifyBell
	notifyTitle
	notifyOSC9
	notifyDesktop // OSC 777
)

// resolveTerminalNotifyMode resolves the mode from the env. Unknown values map to notifyOff.
func resolveTerminalNotifyMode() terminalNotifyMode {
	switch strings.ToLower(strings.TrimSpace(os.Getenv("HARNESS_TERMINAL_NOTIFY"))) {
	case "", "0":
		return notifyOff
	case "1", "bell":
		return notifyBell
	case "title":
		return notifyTitle
	case "osc9":
		return notifyOSC9
	case "notify":
		return notifyDesktop
	default:
		// Unknown values are silent (consistent with the rule)
		return notifyOff
	}
}

// sanitizeTerminalText removes control characters (0x00-0x1F, 0x7F) from title / body.
// To prevent terminal corruption / secret leakage, it passes only printable characters.
func sanitizeTerminalText(s string) string {
	if s == "" {
		return ""
	}
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		// 0x00-0x1F are control characters, 0x7F is DEL
		if r < 0x20 || r == 0x7F {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// BuildTerminalSequence builds the raw OSC sequence for terminalSequence.
//
// If title is empty, only bell mode returns BEL; otherwise it returns an empty string.
// If HARNESS_TERMINAL_NOTIFY is unset, it always returns an empty string (keeps opt-in).
//
// The return value is raw bytes. To turn it into JSON, encode it with json.Marshal.
func BuildTerminalSequence(title, body string) string {
	mode := resolveTerminalNotifyMode()
	if mode == notifyOff {
		return ""
	}

	cleanTitle := sanitizeTerminalText(title)
	cleanBody := sanitizeTerminalText(body)

	// bell mode does not need a title; all other modes require one
	if mode != notifyBell && cleanTitle == "" {
		return ""
	}

	const (
		esc = "\x1b"
		bel = "\x07"
	)

	switch mode {
	case notifyBell:
		return bel
	case notifyTitle:
		return esc + "]0;" + cleanTitle + bel
	case notifyOSC9:
		return esc + "]9;" + cleanTitle + bel
	case notifyDesktop:
		// OSC 777;notify;<title>;<body><BEL>
		if cleanBody != "" {
			return esc + "]777;notify;" + cleanTitle + ";" + cleanBody + bel
		}
		return esc + "]777;notify;" + cleanTitle + bel
	}
	return ""
}

// AugmentWithTerminalSequence adds the terminalSequence field to the hook response map.
// It does nothing if HARNESS_TERMINAL_NOTIFY is unset or title is empty (non-bell).
func AugmentWithTerminalSequence(resp map[string]interface{}, title, body string) {
	if resp == nil {
		return
	}
	seq := BuildTerminalSequence(title, body)
	if seq != "" {
		resp["terminalSequence"] = seq
	}
}
