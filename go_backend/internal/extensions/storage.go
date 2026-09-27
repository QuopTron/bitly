package extensions

import (
	"encoding/json"
	"log"
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

// FilePath devuelve el archivo donde este almacén persiste. Lo usan los tests
// de arranque para comprobar que una extensión escribe dentro de la carpeta de
// la app y no en el directorio de trabajo del proceso.
func (s *Storage) FilePath() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.filePath
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

// Repoint mueve el almacén a [dataDir] conservando lo que ya había en memoria.
//
// Existe porque un sandbox puede nacer con un dataDir provisional (".") y el
// host confirmar el directorio real recién después. Antes solo se actualizaba
// Sandbox.DataDir y el Store seguía apuntando al CWD, así que cada escritura
// caía en una ruta no escribible y se perdía en silencio: la extensión creía
// haber guardado (no había error) y el arranque siguiente leía vacío. Medido
// con el libro de salud de clientes de ytmusic: "6 guardados" y después
// "nada guardado todavía" en el arranque siguiente.
//
// Las claves ya presentes en memoria tienen prioridad sobre las del disco: son
// las más nuevas (o el mismo valor, si vinieron del mismo archivo).
func (s *Storage) Repoint(dataDir, extID string) {
	if dataDir == "" {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	nuevo := filepath.Join(dataDir, extID+"_store.json")
	if s.filePath == nuevo {
		return
	}
	s.filePath = nuevo
	os.MkdirAll(dataDir, 0755)

	enDisco := make(map[string]string)
	if data, err := os.ReadFile(nuevo); err == nil {
		json.Unmarshal(data, &enDisco)
	}
	for k, v := range s.data {
		if _, ya := enDisco[k]; !ya {
			enDisco[k] = v
		}
	}
	s.data = enDisco
}

// save writes stored data to disk. Devuelve el error en vez de descartarlo:
// un fallo de escritura silencioso hacía que la extensión creyera haber
// persistido algo que nunca llegó al disco.
func (s *Storage) save() error {
	data, err := json.Marshal(s.data)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(s.filePath), 0755); err != nil {
		return err
	}
	if err := os.WriteFile(s.filePath, data, 0644); err != nil {
		log.Printf("[extensions] storage: no se pudo escribir %s: %v", s.filePath, err)
		return err
	}
	return nil
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
