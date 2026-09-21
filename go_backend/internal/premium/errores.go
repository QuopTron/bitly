package premium

import "errors"

// ErrorPremium es un error de validación con un MOTIVO estable.
//
// Por qué existe: el texto (Msg) es copy en español que la UI muestra; si la
// interfaz tuviera que interpretar el texto para decidir qué decir, cambiar
// una palabra rompería la lógica (y al traducir, la rompe seguro). El Motivo
// es un código corto y estable que viaja al cliente, que lo convierte al
// idioma activo.
type ErrorPremium struct {
	Motivo string
	Msg    string
}

func (e *ErrorPremium) Error() string { return e.Msg }

// nuevoError arma un ErrorPremium con motivo y mensaje.
func nuevoError(motivo, msg string) error {
	return &ErrorPremium{Motivo: motivo, Msg: msg}
}

// MotivoDeError devuelve el motivo estable del error, o "" si no es un error
// con motivo conocido (el cliente cae a un mensaje genérico localizado).
func MotivoDeError(err error) string {
	var e *ErrorPremium
	if errors.As(err, &e) {
		return e.Motivo
	}
	return ""
}
