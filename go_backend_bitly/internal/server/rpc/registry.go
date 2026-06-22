package rpc

import (
	"fmt"
	"sync"
)

// Handler is an RPC handler function.
type Handler func(params map[string]interface{}) (interface{}, error)

// Registry maps method names to handlers.
type Registry struct {
	mu       sync.RWMutex
	handlers map[string]Handler
}

// NewRegistry creates an RPC method registry.
func NewRegistry() *Registry {
	return &Registry{
		handlers: make(map[string]Handler),
	}
}

// Register adds a handler for a method.
func (r *Registry) Register(method string, handler Handler) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.handlers[method] = handler
}

// Get retrieves a handler for a method.
func (r *Registry) Get(method string) (Handler, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	h, ok := r.handlers[method]
	if !ok {
		return nil, fmt.Errorf("unknown method: %s", method)
	}
	return h, nil
}

// Dispatch executes an RPC method.
func (r *Registry) Dispatch(method string, params map[string]interface{}) (interface{}, error) {
	handler, err := r.Get(method)
	if err != nil {
		return nil, err
	}
	return handler(params)
}

// Methods returns all registered method names.
func (r *Registry) Methods() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	names := make([]string, 0, len(r.handlers))
	for name := range r.handlers {
		names = append(names, name)
	}
	return names
}
