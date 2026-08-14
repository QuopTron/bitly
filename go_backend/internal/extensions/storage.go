package extensions

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"

	"github.com/dop251/goja"
)

// Storage provides persistent KV storage for extensions.
type Storage struct {
	mu       sync.Mutex
	data     map[string]string
	filePath string
}

// NewStorage creates a KV store backed by a JSON file.
func NewStorage(dataDir, extID string) *Storage {
	os.MkdirAll(dataDir, 0755)
	return &Storage{
		data:     make(map[string]string),
		filePath: filepath.Join(dataDir, extID+"_store.json"),
	}
}

// load reads stored data from disk.
func (s *Storage) load() {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := os.ReadFile(s.filePath)
	if err != nil {
		return
	}
	json.Unmarshal(data, &s.data)
}

// save writes stored data to disk.
func (s *Storage) save() {
	data, _ := json.Marshal(s.data)
	os.WriteFile(s.filePath, data, 0644)
}

// registerStorage adds storage API to the JS sandbox.
func registerStorage(s *Sandbox) {
	if !s.Config.EnableStorage {
		return
	}
	s.Store.load()

	vm := s.VM
	storeObj := vm.NewObject()

	storeObj.Set("get", func(call goja.FunctionCall) goja.Value {
		key := call.Argument(0).String()
		s.Store.mu.Lock()
		val, ok := s.Store.data[key]
		s.Store.mu.Unlock()
		if !ok {
			return goja.Undefined()
		}
		return vm.ToValue(val)
	})

	storeObj.Set("set", func(call goja.FunctionCall) goja.Value {
		key := call.Argument(0).String()
		val := call.Argument(1).String()
		s.Store.mu.Lock()
		s.Store.data[key] = val
		s.Store.mu.Unlock()
		s.Store.save()
		return goja.Undefined()
	})

	storeObj.Set("delete", func(call goja.FunctionCall) goja.Value {
		key := call.Argument(0).String()
		s.Store.mu.Lock()
		delete(s.Store.data, key)
		s.Store.mu.Unlock()
		s.Store.save()
		return goja.Undefined()
	})

	storeObj.Set("clear", func(call goja.FunctionCall) goja.Value {
		s.Store.mu.Lock()
		s.Store.data = make(map[string]string)
		s.Store.mu.Unlock()
		s.Store.save()
		return goja.Undefined()
	})

	storeObj.Set("keys", func(call goja.FunctionCall) goja.Value {
		s.Store.mu.Lock()
		keys := make([]string, 0, len(s.Store.data))
		for k := range s.Store.data {
			keys = append(keys, k)
		}
		s.Store.mu.Unlock()
		return vm.ToValue(keys)
	})

	vm.Set("storage", storeObj)
}
