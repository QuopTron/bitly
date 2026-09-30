// Bridge de export para gomobile — dispatcher genérico RPC.
//
// gomobile solo exporta funciones planas (tipos simples), así que Android y
// Darwin llaman a UNA sola función universal InvokeRPC(metodo, payloadJSON),
// que enruta sobre la tabla única de métodos del backend
// (internal/gobackend/rpc_tabla.go) — la misma que usa el servidor JSON-RPC
// de escritorio. Agregar un método nuevo ahí lo habilita en TODAS las
// plataformas sin tocar este archivo ni el puente nativo.
//
// Se conecta con: internal/gobackend/rpc_tabla.go (tabla única) +
// AppDelegate.swift / MainActivity.kt (lado cliente móvil) y
// BackendIOS / BackendAndroid (Dart).
// Parte del flujo: puente nativo móvil — canal com.bitly/backend.

package gobackend

import (
	"encoding/json"

	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// rpcRespuesta shape JSON-RPC 2.0 de la respuesta del dispatcher.
type rpcRespuesta struct {
	Result interface{} `json:"result,omitempty"`
	Error  string      `json:"error,omitempty"`
}

// InvokeRPC ejecuta `metodo` con `payloadJSON` (mismo formato que el body
// JSON-RPC de escritorio: params como objeto) y devuelve la respuesta como
// JSON {"result": ...} o {"error": "..."}. Siempre devuelve texto no vacío.
func InvokeRPC(metodo string, payloadJSON string) string {
	params := map[string]interface{}{}
	if payloadJSON != "" {
		if err := json.Unmarshal([]byte(payloadJSON), &params); err != nil {
			return `{"error":"payload invalido"}`
		}
	}

	resultado, errStr := backend.DispatchRPC(metodo, params)

	resp := rpcRespuesta{Result: resultado, Error: errStr}
	data, err := json.Marshal(resp)
	if err != nil {
		return `{"error":"fallo serializando respuesta"}`
	}
	return string(data)
}
