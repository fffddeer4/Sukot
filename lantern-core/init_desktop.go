//go:build !android && !ios && !darwin

package lanterncore

import (
	"context"

	"github.com/getlantern/radiance/ipc"

	"github.com/getlantern/lantern/lantern-core/utils"
)

// createClient returns the IPC client the desktop UI process uses. On
// portable (zip) builds no lanternd service owns the IPC endpoint, so the
// in-process fallback first hosts the backend itself (see
// init_desktop_fallback.go); with the service installed this is a no-op and
// the client keeps talking to the service as before.
func createClient(ctx context.Context, opts *utils.Opts) (*ipc.Client, error) {
	startInProcessIPCFallback(ctx, opts)
	return ipc.NewClient(), nil
}
