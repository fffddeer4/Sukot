//go:build !android && !ios && !darwin

package lanterncore

import (
	"context"
	"log/slog"
	"sync"

	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/ipc"

	"github.com/getlantern/lantern/lantern-core/utils"
)

// Desktop builds talk to the radiance backend over local IPC (a named pipe
// on Windows, a unix socket on Linux). The endpoint is normally owned by the
// lanternd service, which the Windows/Linux installer sets up.
//
// Portable (zip) builds have no installed service, so nothing owns the IPC
// endpoint and every request — including importing a proxy config — failed
// with a connection error. startInProcessIPCFallback closes that gap: when a
// liveness probe shows nothing is serving the endpoint, this process claims
// it and hosts the backend itself, so the regular ipc.Client keeps working
// unchanged. When the installed service is present it answers the probe and
// the app stays a pure IPC client exactly as before.
var (
	fallbackMu     sync.Mutex
	fallbackServer *ipc.Server
	fallbackBE     *backend.LocalBackend
)

// startInProcessIPCFallback claims the local IPC endpoint and hosts the
// backend in-process when no daemon owns it. The probe (see
// ipc_probe_windows.go / ipc_probe_unix.go) decides; the only race left is a
// service starting exactly between probe and claim, which the installer
// path never hits in practice (the service starts at boot, the app after it).
func startInProcessIPCFallback(ctx context.Context, opts *utils.Opts) {
	fallbackMu.Lock()
	defer fallbackMu.Unlock()
	if fallbackServer != nil {
		return
	}

	owned, err := ipcEndpointOwned()
	if err != nil {
		slog.Warn("Could not probe the local IPC endpoint; staying a pure IPC client", "error", err)
		return
	}
	if owned {
		slog.Info("IPC endpoint already owned by the lanternd service; staying a pure IPC client")
		return
	}

	// Auth is disabled: the only clients are this very process (or another
	// instance of the same app running as the same user), and a user-hosted
	// endpoint has no service owner SID to authorize against.
	srv := ipc.NewServer(nil, false)
	if err := srv.Start(); err != nil {
		slog.Warn("Could not claim the local IPC endpoint; staying a pure IPC client", "reason", err)
		return
	}

	o := opts
	if o == nil {
		o = &utils.Opts{}
	}
	slog.Info("No lanternd service found; hosting the VPN backend in-process (portable mode)",
		"dataDir", o.DataDir, "logDir", o.LogDir)

	be, err := backend.NewLocalBackend(ctx, backend.Options{
		DataDir:                 o.DataDir,
		LogDir:                  o.LogDir,
		DeviceID:                o.Deviceid,
		LogLevel:                o.LogLevel,
		Locale:                  o.Locale,
		TimeZone:                o.TimeZone,
		TelemetryConsent:        o.TelemetryConsent,
		EnvOverrides:            o.RadianceEnvOverrides(),
		UserMessageCapabilities: utils.UserMessageCapabilities(),
	})
	if err != nil {
		slog.Error("In-process backend unavailable; IPC requests will fail", "error", err)
		srv.Close()
		return
	}
	be.Start()
	srv.SetBackend(be)

	// Keep references for the lifetime of the process so the server and the
	// backend are never garbage-collected while in use.
	fallbackServer = srv
	fallbackBE = be
	slog.Info("In-process IPC fallback active")
}
