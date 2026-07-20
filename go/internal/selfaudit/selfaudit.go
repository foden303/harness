// Package selfaudit detects hook injection in settings.local.json.
// Harness no longer writes any delivery hooks of its own to settings.local.json,
// so the allowlist is empty: every command-type hook found there is reported as
// a potential injection (a detective backstop against persistence).
package selfaudit

import (
	"encoding/json"
	"strings"
)

type HookEntry struct {
	Event   string // "Stop" / "SessionStart" etc.
	Type    string // "command" / "subagent" etc.
	Command string
}

type Report struct {
	Known        []HookEntry // CCH-known hooks
	Unknown      []HookEntry // unknown (possible injection)
	WarningCount int         // = len(Unknown)
}

// CCHKnownHooks are the command patterns this package recognizes as allowlisted.
// Matching is by prefix on the command string. It is currently empty: harness
// writes no delivery hooks of its own to settings.local.json, so any command
// hook present there is treated as unknown (a potential injection).
//
// Design principle: don't add patterns that are too broad. A bare "bin/harness"
// prefix is forbidden (it would sweep in other harness subcommands). Include the
// specific subcommand name.
var CCHKnownHooks = []string{}

// Audit takes the bytes of settings.local.json as input and classifies hook
// injection. Invalid JSON or a missing hooks field returns 0 warnings and an
// empty Report (fail-open).
func Audit(settingsLocalJSON []byte) (Report, error) {
	entries := extractCommandHooks(settingsLocalJSON)
	if entries == nil {
		return Report{}, nil
	}

	var known, unknown []HookEntry
	for _, entry := range entries {
		if IsKnown(entry.Command) {
			known = append(known, entry)
		} else {
			unknown = append(unknown, entry)
		}
	}

	return Report{
		Known:        known,
		Unknown:      unknown,
		WarningCount: len(unknown),
	}, nil
}

// IsKnown reports whether a command string prefix-matches any of CCHKnownHooks.
func IsKnown(command string) bool {
	trimmed := strings.TrimSpace(command)
	for _, prefix := range CCHKnownHooks {
		if strings.HasPrefix(trimmed, prefix) {
			return true
		}
	}
	return false
}

func extractCommandHooks(data []byte) []HookEntry {
	var root map[string]json.RawMessage
	if err := json.Unmarshal(data, &root); err != nil {
		return nil
	}
	hooksRaw, ok := root["hooks"]
	if !ok {
		return nil
	}
	var hooks map[string]json.RawMessage
	if err := json.Unmarshal(hooksRaw, &hooks); err != nil {
		return nil
	}

	var entries []HookEntry
	for event, eventRaw := range hooks {
		var items []json.RawMessage
		if err := json.Unmarshal(eventRaw, &items); err != nil {
			continue
		}
		for _, item := range items {
			collectCommandHooks(event, item, &entries)
		}
	}
	return entries
}

func collectCommandHooks(event string, raw json.RawMessage, entries *[]HookEntry) {
	var node struct {
		Matcher string `json:"matcher"`
		Hooks   []struct {
			Type    string `json:"type"`
			Command string `json:"command"`
		} `json:"hooks"`
		Type    string `json:"type"`
		Command string `json:"command"`
	}
	if err := json.Unmarshal(raw, &node); err != nil {
		return
	}

	if len(node.Hooks) > 0 {
		for _, hook := range node.Hooks {
			if hook.Type == "command" && strings.TrimSpace(hook.Command) != "" {
				*entries = append(*entries, HookEntry{
					Event:   event,
					Type:    hook.Type,
					Command: hook.Command,
				})
			}
		}
		return
	}

	if node.Type == "command" && strings.TrimSpace(node.Command) != "" {
		*entries = append(*entries, HookEntry{
			Event:   event,
			Type:    node.Type,
			Command: node.Command,
		})
	}
}
