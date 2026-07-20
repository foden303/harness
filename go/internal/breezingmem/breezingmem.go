package breezingmem

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// Client reads breezing decision history from harness-mem (fail-open).
//
// The write half of this client (RecordEvent / IngestBrief, posting breezing
// lifecycle events and confirmed brief cards) was removed before v1.0.0 along
// with its only emitter, the in-process `harness work --team` orchestrator.
// What remains is the read path used by `harness mem search-similar`.
type Client struct {
	BaseURL    string
	HTTPClient *http.Client
	Logger     io.Writer
	homeDir    func() (string, error)
}

// New returns a Client with env-derived BaseURL and a 1s HTTP timeout.
func New() *Client {
	host := os.Getenv("HARNESS_MEM_HOST")
	if host == "" {
		host = "127.0.0.1"
	}
	port := os.Getenv("HARNESS_MEM_PORT")
	if port == "" {
		port = "37888"
	}
	return &Client{
		BaseURL:    "http://" + host + ":" + port,
		HTTPClient: &http.Client{Timeout: time.Second},
		Logger:     os.Stderr,
		homeDir:    os.UserHomeDir,
	}
}

func (c *Client) configured() bool {
	homeDir := c.homeDir
	if homeDir == nil {
		homeDir = os.UserHomeDir
	}
	home, err := homeDir()
	if err != nil {
		return false
	}
	harnessMemHome := os.Getenv("HARNESS_MEM_HOME")
	if harnessMemHome == "" {
		harnessMemHome = filepath.Join(home, ".harness-mem")
	}
	claudeMem := filepath.Join(home, ".claude-mem")
	if _, err := os.Stat(harnessMemHome); os.IsNotExist(err) {
		if _, legacyErr := os.Stat(claudeMem); os.IsNotExist(legacyErr) {
			return false
		}
	}
	return true
}

func (c *Client) logger() io.Writer {
	if c.Logger != nil {
		return c.Logger
	}
	return io.Discard
}

func (c *Client) httpClient() *http.Client {
	if c.HTTPClient != nil {
		return c.HTTPClient
	}
	return &http.Client{Timeout: time.Second}
}
