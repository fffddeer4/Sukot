//go:build !android && !ios && !darwin

// Command fallbacke2e simulates the desktop lifecycle for manual verification:
//
//	go run ./lantern-core/cmd/fallbacke2e -name A -host   (first  -> hosts backend in-process)
//	go run ./lantern-core/cmd/fallbacke2e -name B         (second -> listen fails, pure client;
//	                                                       its requests are served by A)
//
// Both instances must import the user's VLESS config successfully, printing
// the resulting tags. This validates that the in-process fallback coexists
// with an endpoint owner (the service case).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/getlantern/lantern/lantern-core"
	"github.com/getlantern/lantern/lantern-core/utils"
)

const userVLESSConfig = "vless://eead0cdf-bb4c-44b4-a953-7007b0dd7dd0@cf-config-panel.sukot.workers.dev:443?path=%2F%3Fed%3D2048%26proxyip%3Dproxyip.nl.cmliussss.net&security=tls&alpn=http%2F1.1&encryption=none&insecure=0&host=cf-config-panel.sukot.workers.dev&fp=chrome&type=ws&allowInsecure=0&sni=cf-config-panel.sukot.workers.dev#SUKOT-MCI-Gdgdg-EX-proxyip-nl"

type nopEmitter struct{}

func (nopEmitter) SendEvent(*utils.FlutterEvent) {}

func main() {
	name := flag.String("name", "A", "instance name")
	host := flag.Bool("host", false, "expect to host the backend (first instance)")
	flag.Parse()

	base, err := os.MkdirTemp("", "fallbacke2e-"+*name)
	if err != nil {
		fmt.Printf("[%s] FAIL tempdir: %v\n", *name, err)
		os.Exit(1)
	}
	defer os.RemoveAll(base)

	core, err := lanterncore.New(&utils.Opts{
		DataDir:  filepath.Join(base, "data"),
		LogDir:   filepath.Join(base, "logs"),
		Locale:   "en",
		LogLevel: "info",
	}, nopEmitter{})
	if err != nil {
		fmt.Printf("[%s] FAIL New: %v\n", *name, err)
		os.Exit(1)
	}

	tagsJSON, err := core.AddServersByURL(userVLESSConfig, true)
	if err != nil {
		fmt.Printf("[%s] FAIL AddServersByURL: %v\n", *name, err)
		os.Exit(1)
	}
	var tags []string
	json.Unmarshal(tagsJSON, &tags)
	fmt.Printf("[%s] OK tags=%v\n", *name, tags)

	if *host {
		// Keep the endpoint owned so the second instance can talk to us.
		time.Sleep(30 * time.Second)
	}
}
