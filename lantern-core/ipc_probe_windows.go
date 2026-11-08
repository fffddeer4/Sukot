//go:build windows

package lanterncore

import (
	"errors"
	"os"
)

// ipcEndpointOwned reports whether something already serves the local IPC
// endpoint. On Windows the endpoint is the fixed named pipe (ipc.pipePath in
// radiance). A named-pipe name exists exactly while at least one of its
// server instances is alive, so a successful Stat proves a live owner (the
// lanternd service or another app instance) and there are no stale names to
// clean up.
func ipcEndpointOwned() (bool, error) {
	const pipePath = `\\.\pipe\Lantern\lantern`
	if _, err := os.Stat(pipePath); err == nil {
		return true, nil
	} else if errors.Is(err, os.ErrNotExist) {
		return false, nil
	} else {
		return false, err
	}
}
