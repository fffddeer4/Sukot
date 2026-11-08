//go:build !android && !ios && !darwin

package lanterncore_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/getlantern/lantern/lantern-core"
	"github.com/getlantern/lantern/lantern-core/utils"
)

// The exact config the user reported failing on Windows (manually pasted and
// via QR): a Cloudflare-Workers VLESS config whose WS path carries
// ?ed=2048&proxyip=... parameters.
const userVLESSConfig = "vless://eead0cdf-bb4c-44b4-a953-7007b0dd7dd0@cf-config-panel.sukot.workers.dev:443?path=%2F%3Fed%3D2048%26proxyip%3Dproxyip.nl.cmliussss.net&security=tls&alpn=http%2F1.1&encryption=none&insecure=0&host=cf-config-panel.sukot.workers.dev&fp=chrome&type=ws&allowInsecure=0&sni=cf-config-panel.sukot.workers.dev#SUKOT-MCI-Gdgdg-EX-proxyip-nl"

type nopEmitter struct{}

func (nopEmitter) SendEvent(*utils.FlutterEvent) {}

// TestDesktopFallbackEndToEndWithUserConfig mirrors the Windows/zip launch:
// no lanternd service owns the IPC endpoint, so createClient must start the
// in-process fallback (init_desktop_fallback.go) and every Core call — most
// importantly AddServersByURL with the user's config — must succeed through
// the regular client afterwards.
func TestDesktopFallbackEndToEndWithUserConfig(t *testing.T) {
	if testing.Short() {
		t.Skip("e2e test")
	}
	base := t.TempDir()
	dataDir := filepath.Join(base, "data")
	logDir := filepath.Join(base, "logs")
	for _, d := range []string{dataDir, logDir} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", d, err)
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	core, err := lanterncore.New(&utils.Opts{
		DataDir:  dataDir,
		LogDir:   logDir,
		Locale:   "en",
		LogLevel: "debug",
	}, nopEmitter{})
	if err != nil {
		t.Fatalf("lanterncore.New (fallback should have hosted the backend): %v", err)
	}

	// 1. The user's exact flow: paste the config, hit save.
	start := time.Now()
	tagsJSON, err := core.AddServersByURL(userVLESSConfig, true)
	if err != nil {
		t.Fatalf("AddServersByURL failed (this is the error Windows users saw): %v", err)
	}
	t.Logf("AddServersByURL ok in %s: %s", time.Since(start), tagsJSON)

	var tags []string
	if err := json.Unmarshal(tagsJSON, &tags); err != nil {
		t.Fatalf("tags JSON: %v", err)
	}
	if len(tags) == 0 {
		t.Fatal("no tags returned")
	}
	tag := tags[0]
	if tag != "SUKOT-MCI-Gdgdg-EX-proxyip-nl" {
		t.Logf("note: tag %q", tag)
	}

	// 2. The server must really be persisted with the full WS path intact —
	// the second bug: the stripped path made CF-worker configs connect but
	// never tunnel (no ping, no traffic).
	client := core.Client()
	srv, found, err := client.GetServerByTag(ctx, tag)
	if err != nil || !found {
		t.Fatalf("server %q not persisted: found=%v err=%v", tag, found, err)
	}
	raw, _ := json.Marshal(srv)
	t.Logf("persisted server: %s", raw)

	if !strings.Contains(string(raw), "/?ed=2048&proxyip=proxyip.nl.cmliussss.net") &&
		!strings.Contains(string(raw), "/?ed=2048\\u0026proxyip=proxyip.nl.cmliussss.net") {
		t.Errorf("WS path not preserved verbatim in stored server:\n%s", raw)
	}
	if !strings.Contains(string(raw), "eead0cdf-bb4c-44b4-a953-7007b0dd7dd0") {
		t.Errorf("UUID missing from stored server:\n%s", raw)
	}
	if !strings.Contains(string(raw), "cf-config-panel.sukot.workers.dev") {
		t.Errorf("server host missing from stored server:\n%s", raw)
	}

	// 3. The server list the UI displays must include it.
	servers, err := client.Servers(ctx)
	if err != nil {
		t.Fatalf("Servers() failed: %v", err)
	}
	foundInList := false
	for _, s := range servers {
		if s.Tag == tag {
			foundInList = true
			break
		}
	}
	if !foundInList {
		t.Errorf("tag %q missing from Servers() list (%d servers)", tag, len(servers))
	}
}
