package gobackend

import (
	"strings"
	"testing"
)

// TestInvokeRPCPing verifica que el dispatcher genérico enrute ping → pong.
func TestInvokeRPCPing(t *testing.T) {
	resp := InvokeRPC("ping", "")
	if !strings.Contains(resp, `"result":"pong"`) {
		t.Fatalf("ping debe responder pong, obtuvo: %s", resp)
	}
}

// TestInvokeRPCMetodoDesconocido verifica el error para métodos no routados.
func TestInvokeRPCMetodoDesconocido(t *testing.T) {
	resp := InvokeRPC("metodoQueNoExiste", "")
	if !strings.Contains(resp, `"error"`) {
		t.Fatalf("método desconocido debe devolver error, obtuvo: %s", resp)
	}
}

// TestInvokeRPCInitGlobalState verifica un método con objeto como resultado
// (el JSON de estado global) sin depender de dirs de datos reales.
func TestInvokeRPCInitGlobalState(t *testing.T) {
	resp := InvokeRPC("initGlobalState", "")
	if resp == "" || strings.Contains(resp, `"error"`) {
		t.Fatalf("initGlobalState no debe fallar sin payload, obtuvo: %s", resp)
	}
}
