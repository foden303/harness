package breezingmem

import (
	"io"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Shared fixtures for the read-path tests in search_test.go. The write-path
// tests (RecordEvent / IngestBrief 3-state coverage) were removed with the
// write API itself; the surviving 3-state coverage lives in search_test.go
// as TestSearchSimilar_{Healthy,NotConfigured,Unreachable}.

func configuredHome(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	if err := os.MkdirAll(filepath.Join(home, ".harness-mem"), 0o700); err != nil {
		t.Fatal(err)
	}
	return home
}

func newTestClient(t *testing.T, home string, server *httptest.Server, logger io.Writer) *Client {
	t.Helper()
	return &Client{
		BaseURL:    server.URL,
		HTTPClient: server.Client(),
		Logger:     logger,
		homeDir:    func() (string, error) { return home, nil },
	}
}

// The workgraph signal store owns durable cross-session handoff; this client
// must never reach for it. Boundary is asserted on the source itself so a
// future edit cannot quietly cross it.
func TestBreezingMem_NoSignalAPIReferences(t *testing.T) {
	data, err := os.ReadFile("breezingmem.go")
	if err != nil {
		t.Fatal(err)
	}
	lower := strings.ToLower(string(data))
	for _, needle := range []string{"/v1/signals", "signal_send", "signal_read", "signal_ack"} {
		if strings.Contains(lower, needle) {
			t.Fatalf("breezingmem.go must not reference signal API %q", needle)
		}
	}
}
