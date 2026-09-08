package cooldown

import (
	"math/rand"
	"time"
)

// MarkError enfría [name] a nivel provider cuando [errMsg] indica rate-limit o bloqueo.
func MarkError(name, errMsg string) {
	marcarError(claveOp(name, ""), errMsg)
}

// MarkOpError enfría [name] solo dentro de la clase de operación [op].
func MarkOpError(name, op, errMsg string) {
	marcarError(claveOp(name, op), errMsg)
}

func marcarError(clave, errMsg string) {
	if !limitadoObloqueado(errMsg) {
		return
	}
	mutex.Lock()
	defer mutex.Unlock()
	ahora := time.Now()
	base := duracionCooldown
	// Providers con verificación pendiente reciben ventana más corta: el usuario
	// puede completar el challenge en cualquier momento.
	if requiereVerificacion(errMsg) {
		base = duracionCooldownVerificacion
	}
	if hasta, ok := enfriados[clave]; ok && ahora.Before(hasta) {
		d := time.Until(hasta) * 2
		if d < base {
			d = base
		}
		if d > duracionCooldownMax {
			d = duracionCooldownMax
		}
		enfriados[clave] = ahora.Add(d)
		return
	}
	enfriados[clave] = ahora.Add(base + time.Duration(rand.Int63n(int64(jitterMax+1))))
}

// jitterMax dispersa ventanas iniciales idénticas para que un estallido de 429s
// no haga que todos los providers se enfríen y reintenten en bloque.
const jitterMax = 15 * time.Second

// MarkOk quita el cooldown de [name] tras una operación exitosa.
func MarkOk(name string) {
	marcarOK(claveOp(name, ""))
}

// MarkOpOk quita el cooldown de [name] solo dentro de la clase de operación [op].
func MarkOpOk(name, op string) {
	marcarOK(claveOp(name, op))
}

// marcarOK elimina el cooldown de [clave] tras una operación exitosa.
func marcarOK(clave string) {
	mutex.Lock()
	defer mutex.Unlock()
	delete(enfriados, clave)
}
