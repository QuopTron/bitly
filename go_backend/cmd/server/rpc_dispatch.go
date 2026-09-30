package main

import (
	"encoding/json"
	"io"
	"net/http"

	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// rpcRequest is the JSON-RPC 2.0 request shape from DesktopBackend.
type rpcRequest struct {
	JSONRPC string                 `json:"jsonrpc"`
	ID      int64                  `json:"id"`
	Method  string                 `json:"method"`
	Params  map[string]interface{} `json:"params"`
}

// registerRPCRoute registers the JSON-RPC endpoint used by DesktopBackend.
func registerRPCRoute(mux *http.ServeMux) {
	mux.HandleFunc("/rpc", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, `{"jsonrpc":"2.0","error":"usa POST"}`, http.StatusMethodNotAllowed)
			return
		}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, `{"jsonrpc":"2.0","error":"cuerpo inválido"}`, 400)
			return
		}
		var req rpcRequest
		if err := json.Unmarshal(body, &req); err != nil || req.Method == "" {
			http.Error(w, `{"jsonrpc":"2.0","error":"payload inválido"}`, 400)
			return
		}
		result, rpcErr := dispatchRPC(req.Method, req.Params)
		resp := map[string]interface{}{"jsonrpc": "2.0", "id": req.ID}
		if rpcErr != "" {
			resp["error"] = rpcErr
		} else {
			resp["result"] = result
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})
}

// dispatchRPC enruta un método JSON-RPC sobre la tabla única de métodos
// (internal/gobackend/rpc_tabla.go), la misma que usan Android e iOS vía
// InvokeRPC. Aquí NO hay lista de métodos propia: cualquier método nuevo se
// agrega solo en esa tabla y vale para todas las plataformas.
func dispatchRPC(method string, params map[string]interface{}) (interface{}, string) {
	return backend.DispatchRPC(method, params)
}
