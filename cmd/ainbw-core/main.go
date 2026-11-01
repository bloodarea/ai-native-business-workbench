package main

import (
	"flag"
	"github.com/ainbw/ainbw/internal/platform/plugins"
	"github.com/ainbw/ainbw/internal/platform/store"
	"github.com/ainbw/ainbw/internal/transport/httpapi"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:4177", "loopback listen address")
	dataDir := flag.String("data-dir", ".local/data", "local data directory")
	pluginsDir := flag.String("plugins-dir", "plugins", "plugin manifest directory")
	webDir := flag.String("web-dir", "", "optional built React frontend directory")
	flag.Parse()
	if !httpapi.IsLoopbackAddress(*addr) {
		log.Fatal("Core only allows loopback listen addresses")
	}
	if err := os.MkdirAll(*dataDir, 0700); err != nil {
		log.Fatal(err)
	}
	db := store.NewJSONStore(filepath.Join(*dataDir, "project-tree.json"))
	catalog := plugins.NewCatalog(*pluginsDir)
	server := httpapi.New(db, catalog, *webDir)
	log.Printf("AINBW Go Core v0.2.0 listening on http://%s", *addr)
	log.Printf("data=%s, plugins=%s", *dataDir, *pluginsDir)
	log.Fatal(http.ListenAndServe(*addr, server))
}
