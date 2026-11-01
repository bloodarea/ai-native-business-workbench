package plugins

import (
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Manifest struct {
	ID            string         `json:"id"`
	Name          string         `json:"name"`
	Version       string         `json:"version"`
	Kind          string         `json:"kind"`
	Status        string         `json:"status"`
	Permissions   []string       `json:"permissions,omitempty"`
	Contributions map[string]any `json:"contributions,omitempty"`
}
type Catalog struct{ root string }

func NewCatalog(root string) *Catalog { return &Catalog{root: root} }
func (c *Catalog) List() ([]Manifest, error) {
	list := []Manifest{}
	err := filepath.WalkDir(c.root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if os.IsNotExist(walkErr) {
				return nil
			}
			return walkErr
		}
		if entry.IsDir() {
			if path == c.root {
				return nil
			}
			if filepath.Dir(path) == c.root {
				return nil
			}
			return filepath.SkipDir
		}
		if entry.Name() != "plugin.json" {
			return nil
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var m Manifest
		if err = json.Unmarshal(raw, &m); err != nil {
			return err
		}
		if m.ID == "" || m.Name == "" || m.Version == "" || !strings.Contains(m.ID, ".") {
			return nil
		}
		list = append(list, m)
		return nil
	})
	sort.Slice(list, func(i, j int) bool { return list[i].ID < list[j].ID })
	return list, err
}
