package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
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

// dispatchRPC routes a JSON-RPC method to the Go backend flat exports.
// Each domain (core/media/extra) tiene su propio dispatcher; el primero que
// reconoce el método responde y los demás se saltan.
func dispatchRPC(method string, params map[string]interface{}) (interface{}, string) {
	if res, errStr, handled := dispatchCore(method, params); handled {
		return res, errStr
	}
	if res, errStr, handled := dispatchMedia(method, params); handled {
		return res, errStr
	}
	if res, errStr, handled := dispatchExtra(method, params); handled {
		return res, errStr
	}
	return nil, "método no encontrado: " + method
}

// rpcBody serializa todos los params como el payload JSON que esperan las
// funciones planas del backend (casi todas reciben la cadena cruda).
func rpcBody(params map[string]interface{}) string {
	data, _ := json.Marshal(params)
	return string(data)
}

// rpcGet extrae un param individual como string (o "" si falta/no es texto).
func rpcGet(params map[string]interface{}, key string) string {
	if v, ok := params[key]; ok && v != nil {
		return toString(v)
	}
	return ""
}

// intDe extrae un param numérico con un valor por defecto.
func intDe(params map[string]interface{}, key string, def int) int {
	if v, ok := params[key]; ok && v != nil {
		if f, ok := v.(float64); ok {
			return int(f)
		}
		if s, ok := v.(string); ok {
			var n int
			if _, err := fmt.Sscanf(s, "%d", &n); err == nil {
				return n
			}
		}
	}
	return def
}

// toString convierte un valor JSON a su representación de texto.
func toString(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	if f, ok := v.(float64); ok {
		if f == float64(int64(f)) {
			return jsonInt(int64(f))
		}
		data, _ := json.Marshal(f)
		return string(data)
	}
	if b, ok := v.(bool); ok {
		if b {
			return "true"
		}
		return "false"
	}
	data, _ := json.Marshal(v)
	return string(data)
}

func jsonInt(v int64) string {
	data, _ := json.Marshal(v)
	return string(data)
}
