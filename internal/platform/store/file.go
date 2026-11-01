package store

import (
	"encoding/json"
	"errors"
	"github.com/ainbw/ainbw/internal/domain/project"
	"os"
	"path/filepath"
	"sync"
)

type JSONStore struct {
	path string
	mu   sync.Mutex
}

func NewJSONStore(path string) *JSONStore { return &JSONStore{path: path} }
func (s *JSONStore) Read() (project.Tree, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return project.Tree{Initialized: false, Categories: []project.Category{}}, nil
	}
	if err != nil {
		return project.Tree{}, err
	}
	var tree project.Tree
	if err = json.Unmarshal(data, &tree); err != nil {
		return project.Tree{}, err
	}
	if tree.Categories == nil {
		tree.Categories = []project.Category{}
	}
	return tree, nil
}
func (s *JSONStore) Write(tree project.Tree) (project.Tree, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	tree.Initialized = true
	if tree.Categories == nil {
		tree.Categories = []project.Category{}
	}
	data, err := json.MarshalIndent(tree, "", "  ")
	if err != nil {
		return project.Tree{}, err
	}
	if err = os.MkdirAll(filepath.Dir(s.path), 0700); err != nil {
		return project.Tree{}, err
	}
	tmp, err := os.CreateTemp(filepath.Dir(s.path), ".tree-*.tmp")
	if err != nil {
		return project.Tree{}, err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if err = tmp.Chmod(0600); err == nil {
		_, err = tmp.Write(data)
	}
	if err == nil {
		err = tmp.Sync()
	}
	closeErr := tmp.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		return project.Tree{}, err
	}
	if err = os.Rename(name, s.path); err != nil {
		return project.Tree{}, err
	}
	return tree, nil
}
