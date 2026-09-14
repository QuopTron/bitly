// Bridge de export para gomobile — Soulseek.
//
// POR QUÉ ESTE ARCHIVO EXISTE
// En Android/iOS el cliente Dart hace `MethodChannel.invokeMethod(nombre)`, y
// el lado nativo resuelve ese nombre por REFLEXIÓN contra las funciones
// exportadas del paquete raíz (MainActivity.dispatchGoCall busca un método
// Java homónimo, y gomobile genera uno por cada función Go exportada).
//
// Es decir: que el método esté en el dispatcher JSON-RPC de escritorio
// (rpc_dispatch_extras.go) NO lo hace visible en el celular. Sin este wrapper
// plano, el celular contesta "Go method soulseekConectar not found" — que es
// exactamente lo que pasó hasta ahora.
//
// Se conecta con: internal/gobackend.ConectarSoulseek (la lógica real).
// Parte del flujo: Ajustes → Más → Soulseek → botón "Siguiente".

package gobackend

import gobackend "github.com/zarz/bitly/go_backend/internal/gobackend"

// SoulseekConectar re-exportado desde internal/gobackend: con el nombre que
// eligió el usuario genera la contraseña y conecta (en Soulseek conectar ES
// registrarse). Devuelve {ok, usuario, password, password_generada, mensaje}.
func SoulseekConectar(payload string) string {
	return gobackend.ConectarSoulseek(payload)
}
