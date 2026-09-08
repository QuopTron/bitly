package gobackend

import (
	"fmt"

	core "github.com/zarz/bitly/go_backend/internal/core"
)

// SetMemoryLimitMB ajusta el tope blando de RAM del backend (en MiB).
//
// Flutter la llama al arrancar con la memoria real del dispositivo (p. ej.
// la mitad de la RAM total) para que el GC de Go recolecte antes de agotar
// la memoria — en móviles sin esto el heap puede crecer hasta el OOM. Si no
// se llama, se usa el default (1 GiB). Devuelve "ok" o un mensaje de error.
//
// Es exportada para gomobile bind, por eso devuelve string (los tipos del
// puente deben ser básicos).
func SetMemoryLimitMB(n int) string {
	if n <= 0 {
		return fmt.Sprintf("error: el límite debe ser > 0 MiB (recibido %d)", n)
	}
	core.FijarLimiteMemoriaMB(n)
	return "ok"
}
