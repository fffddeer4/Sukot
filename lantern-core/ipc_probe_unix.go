//go:build !windows && !android && !ios && !darwin

package lanterncore

import (
	"net"
	"time"
)

// ipcEndpointOwned reports whether something already serves the local IPC
// endpoint. On unix-like desktops the endpoint is the fixed unix socket
// (ipc.socketPath in radiance). Only a successful dial proves a live owner:
// any other outcome — missing file or stale socket left behind by a crashed
// daemon — means this process may claim the endpoint (listen() removes a
// stale file before binding).
func ipcEndpointOwned() (bool, error) {
	const socketPath = "/var/run/lantern/lanternd.sock"
	conn, err := net.DialTimeout("unix", socketPath, time.Second)
	if err != nil {
		return false, nil
	}
	conn.Close()
	return true, nil
}
