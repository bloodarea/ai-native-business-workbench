package httpapi

import (
	"github.com/ainbw/ainbw/internal/platform/plugins"
	"github.com/ainbw/ainbw/internal/platform/store"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func newTestServer(t *testing.T) http.Handler {
	t.Helper()
	temp := t.TempDir()
	return New(store.NewJSONStore(filepath.Join(temp, "state.json")), plugins.NewCatalog(filepath.Join(temp, "plugins")), "")
}
func TestLoopback(t *testing.T) {
	for _, tt := range []struct {
		addr string
		ok   bool
	}{{"127.0.0.1:4177", true}, {"localhost:4177", true}, {"0.0.0.0:4177", false}, {"192.168.1.1:4177", false}} {
		if got := IsLoopbackAddress(tt.addr); got != tt.ok {
			t.Errorf("%s: %v != %v", tt.addr, got, tt.ok)
		}
	}
}
func TestHealthAndProjectTree(t *testing.T) {
	h := newTestServer(t)
	check := func(method, path, body, origin string, want int) {
		t.Helper()
		r := httptest.NewRequest(method, path, strings.NewReader(body))
		if body != "" {
			r.Header.Set("Content-Type", "application/json")
		}
		if origin != "" {
			r.Header.Set("Origin", origin)
		}
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != want {
			t.Errorf("%s %s: %d != %d: %s", method, path, w.Code, want, w.Body.String())
		}
	}
	check("GET", "/api/v1/health", "", "", 200)
	check("GET", "/api/v1/project-tree", "", "", 200)
	check("PUT", "/api/v1/project-tree", `{"categories":[{"id":"a","name":"软件研发","open":true,"projects":[]}]}`, "http://localhost:5273", 200)
	check("PUT", "/api/v1/project-tree", `{"categories":[]}`, "https://example.com", 403)
	check("PUT", "/api/v1/project-tree", `{"categories":[{"id":"bad","name":"","projects":[]}]}`, "", 400)
	check("GET", "/api/v1/plugins", "", "", 200)
	check("GET", "/api/v1/capabilities", "", "", 200)
}

func TestPersistedFile(t *testing.T) {
	root := t.TempDir()
	db := store.NewJSONStore(filepath.Join(root, "project-tree.json"))
	srv := New(db, plugins.NewCatalog(filepath.Join(root, "plugins")), "")
	put := httptest.NewRequest("PUT", "/api/v1/project-tree", strings.NewReader(`{"categories":[{"id":"c1","name":"Category","open":true,"projects":[{"id":"p1","name":"Project"}]}]}`))
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, put)
	if w.Code != 200 {
		t.Fatal(w.Code, w.Body.String())
	}
	tree, err := store.NewJSONStore(filepath.Join(root, "project-tree.json")).Read()
	if err != nil || !tree.Initialized || len(tree.Categories) != 1 || len(tree.Categories[0].Projects) != 1 {
		t.Fatalf("tree not persisted: %#v %v", tree, err)
	}
}
