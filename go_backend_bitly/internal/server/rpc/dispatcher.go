package rpc

import (
	"encoding/json"
	"net/http"
	"strings"
)

// RPCRequest is a JSON-RPC-like request.
type RPCRequest struct {
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params"`
}

// RPCResponse is a JSON-RPC-like response.
type RPCResponse struct {
	Result interface{} `json:"result,omitempty"`
	Error  string      `json:"error,omitempty"`
}

// Dispatcher handles incoming RPC requests.
type Dispatcher struct {
	Registry *Registry
}

// NewDispatcher creates a new dispatcher.
func NewDispatcher() *Dispatcher {
	return &Dispatcher{
		Registry: NewRegistry(),
	}
}

// ServeHTTP handles RPC HTTP requests.
func (d *Dispatcher) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(RPCResponse{Error: "method not allowed"})
		return
	}

	var req RPCRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		json.NewEncoder(w).Encode(RPCResponse{Error: "invalid JSON: " + err.Error()})
		return
	}

	result, err := d.Registry.Dispatch(req.Method, req.Params)
	if err != nil {
		json.NewEncoder(w).Encode(RPCResponse{Error: err.Error()})
		return
	}
	json.NewEncoder(w).Encode(RPCResponse{Result: result})
}

// Sp retrieves a string parameter from the params map.
func Sp(params map[string]interface{}, key string) string {
	v, _ := params[key].(string)
	return strings.TrimSpace(v)
}

// Sn retrieves a numeric parameter from the params map.
func Sn(params map[string]interface{}, key string) int {
	switch v := params[key].(type) {
	case float64:
		return int(v)
	case int:
		return v
	default:
		return 0
	}
}

// Sb retrieves a boolean parameter from the params map.
func Sb(params map[string]interface{}, key string) bool {
	switch v := params[key].(type) {
	case bool:
		return v
	case string:
		s := strings.TrimSpace(v)
		return s == "true" || s == "1"
	case float64:
		return v != 0
	default:
		return false
	}
}
