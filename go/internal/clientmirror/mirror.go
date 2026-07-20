// Package clientmirror compares skills/ SSOT against host skill mirror roots
// and emits mirror-state.v1 drift reports.
package clientmirror

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"time"
)

const (
	SchemaRelPath       = "templates/schemas/mirror-state.v1.json"
	SchemaVersion       = "mirror-state.v1"
	SchemaURL           = "mirror-state.v1"
	SharedSSOTRel       = "skills"
	ReasonNotConfigured = "not-configured"
	ReasonInSync        = "in-sync"
	ReasonDrift         = "drift"
)

// mirrorRoots are the read-only distribution copies of skills/. A root that
// does not exist reports not-configured, never drift.
var mirrorRoots = []string{
	".agents/skills",
}

var compareExclude = map[string]struct{}{
	".DS_Store": {},
	".claude":   {},
}

// MirrorEntry is one mirror root status inside mirror-state.v1.
type MirrorEntry struct {
	Root       string   `json:"root"`
	Status     string   `json:"status"`
	DriftCount int      `json:"drift_count"`
	Drifts     []string `json:"drifts,omitempty"`
}

// State is the mirror-state.v1 payload.
type State struct {
	SchemaVersion string        `json:"schema_version"`
	Fingerprint   string        `json:"fingerprint"`
	Healthy       bool          `json:"healthy"`
	Reason        string        `json:"reason"`
	Mirrors       []MirrorEntry `json:"mirrors"`
	TS            int64         `json:"ts,omitempty"`
}

// ScanOptions configures mirror scanning.
type ScanOptions struct {
	Now time.Time
}

// Scan walks configured mirror roots and returns mirror-state.v1.
func Scan(repoRoot string, opts ScanOptions) (State, error) {
	if opts.Now.IsZero() {
		opts.Now = time.Now().UTC()
	}
	mirrors := make([]MirrorEntry, 0, len(mirrorRoots))
	for _, root := range mirrorRoots {
		entry, err := scanMirrorRoot(repoRoot, root)
		if err != nil {
			return State{}, err
		}
		mirrors = append(mirrors, entry)
	}
	state := finalizeState(mirrors, opts.Now)
	state.Fingerprint = Fingerprint(state)
	return state, nil
}

// Diff returns drift messages for configured mirrors only.
func Diff(repoRoot string) ([]string, error) {
	state, err := Scan(repoRoot, ScanOptions{})
	if err != nil {
		return nil, err
	}
	var drifts []string
	for _, mirror := range state.Mirrors {
		if mirror.Status == ReasonDrift {
			drifts = append(drifts, mirror.Drifts...)
		}
	}
	sort.Strings(drifts)
	return drifts, nil
}

// Fingerprint returns a stable sha256 fingerprint for mirror state sans ts.
func Fingerprint(state State) string {
	payload := state
	payload.TS = 0
	payload.Fingerprint = ""
	data, err := json.Marshal(payload)
	if err != nil {
		sum := sha256.Sum256([]byte(fmt.Sprintf("%+v", state.Mirrors)))
		return "sha256:" + hex.EncodeToString(sum[:])
	}
	sum := sha256.Sum256(data)
	return "sha256:" + hex.EncodeToString(sum[:])
}

func finalizeState(mirrors []MirrorEntry, now time.Time) State {
	state := State{
		SchemaVersion: SchemaVersion,
		Mirrors:       mirrors,
		TS:            now.Unix(),
	}

	configured := 0
	drifted := 0
	for _, mirror := range mirrors {
		switch mirror.Status {
		case ReasonNotConfigured:
			continue
		case ReasonDrift:
			drifted++
			configured++
		case ReasonInSync:
			configured++
		}
	}

	switch {
	case drifted > 0:
		state.Healthy = false
		state.Reason = ReasonDrift
	case configured > 0:
		state.Healthy = true
		state.Reason = ReasonInSync
	default:
		state.Healthy = true
		state.Reason = ReasonNotConfigured
	}
	return state
}

func scanMirrorRoot(repoRoot, mirrorRel string) (MirrorEntry, error) {
	mirrorPath := filepath.Join(repoRoot, filepath.FromSlash(mirrorRel))
	info, err := os.Stat(mirrorPath)
	if err != nil {
		if os.IsNotExist(err) {
			return MirrorEntry{
				Root:       mirrorRel,
				Status:     ReasonNotConfigured,
				DriftCount: 0,
			}, nil
		}
		return MirrorEntry{}, err
	}
	if !info.IsDir() {
		return MirrorEntry{
			Root:       mirrorRel,
			Status:     ReasonDrift,
			DriftCount: 1,
			Drifts:     []string{fmt.Sprintf("%s is not a directory", mirrorRel)},
		}, nil
	}

	drifts, err := diffDirectoryMirror(repoRoot, mirrorRel, mirrorPath)
	if err != nil {
		return MirrorEntry{}, err
	}

	entry := MirrorEntry{
		Root:       mirrorRel,
		DriftCount: len(drifts),
		Drifts:     drifts,
	}
	if len(drifts) == 0 {
		entry.Status = ReasonInSync
	} else {
		entry.Status = ReasonDrift
	}
	return entry, nil
}

func diffDirectoryMirror(repoRoot, mirrorRel, mirrorPath string) ([]string, error) {
	entries, err := os.ReadDir(mirrorPath)
	if err != nil {
		return nil, err
	}

	var drifts []string
	for _, entry := range entries {
		if !entry.IsDir() {
			if entry.Name() == "routing-rules.md" {
				if drift := diffRoutingRules(repoRoot, mirrorPath); drift != "" {
					drifts = append(drifts, drift)
				}
			}
			continue
		}
		skill := entry.Name()
		if skill == "node_modules" || skill == ".git" {
			continue
		}
		src := resolveSourceDir(repoRoot, mirrorRel, skill)
		if src == "" {
			continue
		}
		dst := filepath.Join(mirrorPath, skill)
		if link, err := isSymlink(dst); err != nil {
			return nil, err
		} else if link {
			drifts = append(drifts, fmt.Sprintf("symlink %s/%s", mirrorRel, skill))
			continue
		}
		if !dirEqual(src, dst, compareExclude) {
			drifts = append(drifts, fmt.Sprintf("drift %s/%s", mirrorRel, skill))
		}
	}

	if drift := diffRoutingRules(repoRoot, mirrorPath); drift != "" {
		drifts = append(drifts, drift)
	}
	sort.Strings(drifts)
	return drifts, nil
}

func diffRoutingRules(repoRoot, mirrorPath string) string {
	src := filepath.Join(repoRoot, SharedSSOTRel, "routing-rules.md")
	dst := filepath.Join(mirrorPath, "routing-rules.md")
	srcInfo, srcErr := os.Stat(src)
	dstInfo, dstErr := os.Stat(dst)
	if srcErr != nil || dstErr != nil {
		return ""
	}
	if srcInfo.IsDir() || dstInfo.IsDir() {
		return ""
	}
	if !fileEqual(src, dst) {
		return fmt.Sprintf("drift %s/routing-rules.md", relMirrorPath(mirrorPath, repoRoot))
	}
	return ""
}

func resolveSourceDir(repoRoot, _, skill string) string {
	sharedPath := filepath.Join(repoRoot, SharedSSOTRel, skill)
	if info, err := os.Stat(sharedPath); err == nil && info.IsDir() {
		return sharedPath
	}
	return ""
}

func dirEqual(srcDir, dstDir string, exclude map[string]struct{}) bool {
	return dirEqualWithPredicate(srcDir, dstDir, func(name string, _ fs.DirEntry) bool {
		_, skip := exclude[name]
		return skip
	})
}

func dirEqualWithPredicate(srcDir, dstDir string, skip func(name string, entry fs.DirEntry) bool) bool {
	srcEntries, err := os.ReadDir(srcDir)
	if err != nil {
		return false
	}
	dstEntries, err := os.ReadDir(dstDir)
	if err != nil {
		return false
	}

	srcMap := map[string]fs.DirEntry{}
	dstMap := map[string]fs.DirEntry{}
	for _, entry := range srcEntries {
		if skip(entry.Name(), entry) {
			continue
		}
		srcMap[entry.Name()] = entry
	}
	for _, entry := range dstEntries {
		if skip(entry.Name(), entry) {
			continue
		}
		dstMap[entry.Name()] = entry
	}

	if len(srcMap) != len(dstMap) {
		return false
	}
	for name, srcEntry := range srcMap {
		dstEntry, ok := dstMap[name]
		if !ok {
			return false
		}
		srcPath := filepath.Join(srcDir, name)
		dstPath := filepath.Join(dstDir, name)
		if srcEntry.IsDir() != dstEntry.IsDir() {
			return false
		}
		if srcEntry.IsDir() {
			if !dirEqualWithPredicate(srcPath, dstPath, skip) {
				return false
			}
			continue
		}
		if !fileEqual(srcPath, dstPath) {
			return false
		}
	}
	return true
}

func fileEqual(a, b string) bool {
	aData, err := os.ReadFile(a)
	if err != nil {
		return false
	}
	bData, err := os.ReadFile(b)
	if err != nil {
		return false
	}
	return string(aData) == string(bData)
}

func isSymlink(path string) (bool, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return false, err
	}
	return info.Mode()&os.ModeSymlink != 0, nil
}

func relMirrorPath(mirrorPath, repoRoot string) string {
	rel, err := filepath.Rel(repoRoot, mirrorPath)
	if err != nil {
		return mirrorPath
	}
	return filepath.ToSlash(rel)
}

// FindSchemaPath locates mirror-state.v1.json walking up from startDir.
func FindSchemaPath(startDir string) (string, error) {
	dir := startDir
	for {
		candidate := filepath.Join(dir, SchemaRelPath)
		if _, err := os.Stat(candidate); err == nil {
			return candidate, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", fmt.Errorf("mirror-state schema not found from %s", startDir)
}

// DefaultSchemaPath returns mirror-state.v1 schema path under repo root or by walking up.
func DefaultSchemaPath(repoRoot string) string {
	if path, err := FindSchemaPath(repoRoot); err == nil {
		return path
	}
	return filepath.Join(repoRoot, SchemaRelPath)
}
