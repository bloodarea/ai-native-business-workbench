package httpapi

import (
	"encoding/json"
	"errors"
	"github.com/ainbw/ainbw/internal/domain/project"
	"github.com/ainbw/ainbw/internal/platform/plugins"
	"github.com/ainbw/ainbw/internal/platform/store"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const Version = "0.2.0"

type Server struct {
	store   *store.JSONStore
	catalog *plugins.Catalog
	started time.Time
	webDir  string
}

func New(s *store.JSONStore, c *plugins.Catalog, webDir string) http.Handler {
	core := &Server{store: s, catalog: c, started: time.Now(), webDir: webDir}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/health", core.health)
	mux.HandleFunc("GET /api/v1/plugins", core.plugins)
	mux.HandleFunc("GET /api/v1/capabilities", core.capabilities)
	mux.HandleFunc("GET /api/v1/project-tree", core.readTree)
	mux.HandleFunc("PUT /api/v1/project-tree", core.writeTree)
	if webDir != "" {
		mux.Handle("/", SPA(webDir))
	}
	return guardOrigin(mux)
}
func IsLoopbackAddress(addr string) bool {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return false
	}
	ip := net.ParseIP(host)
	return (ip != nil && ip.IsLoopback()) || strings.EqualFold(host, "localhost")
}
func guardOrigin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" && r.Method != "HEAD" && r.Method != "OPTIONS" {
			origin := r.Header.Get("Origin")
			if origin != "" && !allowedOrigin(origin) {
				writeError(w, http.StatusForbidden, "origin_denied")
				return
			}
		}
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "SAMEORIGIN")
		next.ServeHTTP(w, r)
	})
}
func allowedOrigin(origin string) bool {
	for _, prefix := range []string{"http://127.0.0.1:", "http://localhost:", "http://[::1]:"} {
		if strings.HasPrefix(origin, prefix) {
			hostport := strings.TrimPrefix(origin, prefix)
			if hostport != "" && !strings.ContainsAny(hostport, "/@\\") {
				return true
			}
		}
	}
	return false
}
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
func writeError(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, map[string]string{"error": code})
}
func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, map[string]any{"status": "ok", "version": Version, "uptimeSeconds": int(time.Since(s.started).Seconds())})
}
func (s *Server) plugins(w http.ResponseWriter, r *http.Request) {
	list, err := s.catalog.List()
	if err != nil {
		writeError(w, 500, "catalog_error")
		return
	}
	writeJSON(w, 200, map[string]any{"plugins": list})
}
func (s *Server) capabilities(w http.ResponseWriter, r *http.Request) {
	type cap struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Description string `json:"description"`
		Kind        string `json:"kind"`
		Version     string `json:"version"`
	}
	list := []cap{
		{"core.workspace", "工作区与项目树", "项目类型、项目目录与工作区上下文", "service", Version},
		{"core.plugins", "插件清单注册表", "静态发现插件公开能力，不执行任意插件代码", "registry", Version},
		{"core.contracts", "公共契约", "OpenAPI、JSON Schema 与插件 Manifest", "schema", Version},
		{"ui.primitives", "基础 UI 组件", "Button、Card、Modal；原型界面逐步迁移", "ui", Version},
	}
	writeJSON(w, 200, map[string]any{"capabilities": list})
}
func (s *Server) readTree(w http.ResponseWriter, r *http.Request) {
	tree, err := s.store.Read()
	if err != nil {
		writeError(w, 500, "storage_error")
		return
	}
	writeJSON(w, 200, tree)
}
func validTree(categories []project.Category) bool {
	if len(categories) > 1000 {
		return false
	}
	ids := map[string]bool{}
	for _, c := range categories {
		if c.ID == "" || len(c.ID) > 128 || c.Name == "" || len(c.Name) > 256 || ids["c:"+c.ID] || len(c.Projects) > 10000 {
			return false
		}
		ids["c:"+c.ID] = true
		for _, p := range c.Projects {
			if p.ID == "" || len(p.ID) > 128 || p.Name == "" || len(p.Name) > 256 || ids["p:"+p.ID] {
				return false
			}
			ids["p:"+p.ID] = true
		}
	}
	return true
}
func (s *Server) writeTree(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 2<<20)
	defer r.Body.Close()
	var request struct {
		Categories []project.Category `json:"categories"`
	}
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil || request.Categories == nil || !validTree(request.Categories) {
		writeError(w, 400, "invalid_tree")
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		writeError(w, 400, "trailing_data")
		return
	}
	tree, err := s.store.Write(project.Tree{Categories: request.Categories})
	if err != nil {
		writeError(w, 500, "storage_error")
		return
	}
	writeJSON(w, 200, tree)
}
func SPA(dir string) http.Handler {
	fileServer := http.FileServer(http.Dir(dir))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" && r.Method != "HEAD" {
			writeError(w, 405, "method_not_allowed")
			return
		}
		clean := filepath.Clean("/" + r.URL.Path)
		file := filepath.Join(dir, clean)
		info, err := os.Stat(file)
		if err == nil {
			if !info.IsDir() {
				fileServer.ServeHTTP(w, r)
				return
			}
			if _, indexErr := os.Stat(filepath.Join(file, "index.html")); indexErr == nil {
				fileServer.ServeHTTP(w, r)
				return
			}
		}
		if errors.Is(err, os.ErrNotExist) && !strings.Contains(filepath.Base(clean), ".") {
			http.ServeFile(w, r, filepath.Join(dir, "index.html"))
			return
		}
		if r.URL.Path == "/" {
			http.ServeFile(w, r, filepath.Join(dir, "index.html"))
			return
		}
		http.NotFound(w, r)
	})
}
