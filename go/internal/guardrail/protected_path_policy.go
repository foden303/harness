package guardrail

import (
	"path/filepath"

	"github.com/foden303/harness/go/pkg/config"
	"github.com/foden303/harness/go/pkg/hookproto"
)

func resolveProtectedPathAskList(_ hookproto.HookInput, projectRoot string) []hookproto.ProtectedPathAskEntry {
	return readProtectedPathAskListFromHarnessTOML(filepath.Join(projectRoot, "harness.toml"))
}

func readProtectedPathAskListFromHarnessTOML(path string) []hookproto.ProtectedPathAskEntry {
	cfg, err := config.ParseFile(path)
	if err != nil || cfg == nil {
		return nil
	}

	entries := make([]hookproto.ProtectedPathAskEntry, 0, len(cfg.Safety.Guardrail.ProtectedPathAskList))
	for _, entry := range cfg.Safety.Guardrail.ProtectedPathAskList {
		entries = append(entries, hookproto.ProtectedPathAskEntry{
			Path:   entry.Path,
			Reason: entry.Reason,
			Source: path,
		})
	}
	return entries
}
