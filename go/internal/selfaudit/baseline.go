package selfaudit

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
)

const denyBaselineVersion = "deny-baseline.v1"

// DenyBaseline pins the set of deny entries in .claude-plugin/settings.json via a hash.
//
// Design:
//   - deny entries are order-independent (hashed as sorted + canonical JSON)
//   - at startup, ComputeDenyHash on the current settings.json is compared against the recorded baseline
//   - "same" or "added" passes; "removed" refuses startup
//   - the baseline is pinned in-repo as templates/security/deny-baseline.json (text)
type DenyBaseline struct {
	Version         string   `json:"version"`
	CanonicalSHA256 string   `json:"canonical_sha256"`
	Entries         []string `json:"entries"`
}

// ComputeDenyHash normalizes settings.json's permissions.deny into sorted
// unique + JSON and returns the SHA-256 hex. Invalid JSON or a missing deny
// field returns "" (a sentinel just short of fail-loud) + error.
func ComputeDenyHash(settingsJSON []byte) (canonicalSHA256 string, entries []string, err error) {
	entries, err = extractDenyEntries(settingsJSON)
	if err != nil {
		return "", nil, err
	}
	hash, err := hashDenyEntries(entries)
	if err != nil {
		return "", nil, err
	}
	return hash, entries, nil
}

// VerifyDenyNotRegressed compares the recorded baseline against the current
// settings.json and reports whether deny entries have "regressed" (been
// removed). On error or regression it returns false + a detail message;
// otherwise (same or added) true + an empty string.
func VerifyDenyNotRegressed(baseline DenyBaseline, currentSettingsJSON []byte) (ok bool, reason string, err error) {
	_, currentEntries, err := ComputeDenyHash(currentSettingsJSON)
	if err != nil {
		return false, "", err
	}

	currentSet := make(map[string]struct{}, len(currentEntries))
	for _, entry := range currentEntries {
		currentSet[entry] = struct{}{}
	}

	var missing []string
	for _, entry := range baseline.Entries {
		if _, found := currentSet[entry]; !found {
			missing = append(missing, entry)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return false, fmt.Sprintf("deny entry regression: removed %d baseline entr(y/ies): %s", len(missing), strings.Join(missing, ", ")), nil
	}
	return true, "", nil
}

// LoadBaseline reads the repo's deny-baseline.json. A missing file returns
// DenyBaseline{}, false, nil (fail-open, assuming the initial bootstrap).
func LoadBaseline(path string) (DenyBaseline, bool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return DenyBaseline{}, false, nil
		}
		return DenyBaseline{}, false, err
	}
	var baseline DenyBaseline
	if err := json.Unmarshal(data, &baseline); err != nil {
		return DenyBaseline{}, false, err
	}
	return baseline, true, nil
}

func extractDenyEntries(settingsJSON []byte) (entries []string, err error) {
	var root struct {
		Permissions struct {
			Deny []string `json:"deny"`
		} `json:"permissions"`
	}
	if err := json.Unmarshal(settingsJSON, &root); err != nil {
		return nil, fmt.Errorf("parse settings.json: %w", err)
	}
	if root.Permissions.Deny == nil {
		return nil, fmt.Errorf("permissions.deny field missing")
	}

	seen := make(map[string]struct{}, len(root.Permissions.Deny))
	for _, entry := range root.Permissions.Deny {
		trimmed := strings.TrimSpace(entry)
		if trimmed == "" {
			continue
		}
		seen[trimmed] = struct{}{}
	}
	entries = make([]string, 0, len(seen))
	for entry := range seen {
		entries = append(entries, entry)
	}
	sort.Strings(entries)
	return entries, nil
}

func hashDenyEntries(entries []string) (string, error) {
	canonical, err := json.Marshal(entries)
	if err != nil {
		return "", fmt.Errorf("marshal deny entries: %w", err)
	}
	sum := sha256.Sum256(canonical)
	return hex.EncodeToString(sum[:]), nil
}
