package gobackend

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider/soulseek"
)

// ConectarSoulseek es la acción del botón "Siguiente" en
// Ajustes → Credenciales → Soulseek.
//
// Qué hace, en una línea: con el nombre que escribió el usuario, genera la
// contraseña y conecta. En Soulseek conectar ES registrarse — el servidor da
// de alta la cuenta en ese mismo paso —, así que un solo click deja la cuenta
// creada y funcionando.
//
// Contrato Flutter: {usuario, password?} →
//
//	{ok, usuario, password, password_generada, mensaje}
//
// La contraseña vuelve a Flutter a propósito: hay que guardarla y poder
// mostrarla/exportarla después (Soulseek NO tiene recuperación de
// contraseña). Nunca se escribe en logs.
//
// Lo que NO hace, a propósito: inventar un nombre de usuario aleatorio. El
// spec oficial lo prohíbe por escrito y el que se come el baneo es el usuario.
func ConectarSoulseek(payload string) string {
	var params struct {
		Usuario  string `json:"usuario"`
		Password string `json:"password"`
	}
	if strings.TrimSpace(payload) != "" {
		if err := json.Unmarshal([]byte(payload), &params); err != nil {
			return jsonError(err)
		}
	}
	usuario := strings.TrimSpace(params.Usuario)
	if err := soulseek.ValidarUsuario(usuario); err != nil {
		return jsonErrorSoulseek(err)
	}
	cliente, err := clienteSoulseek()
	if err != nil {
		return jsonError(err)
	}

	// La contraseña se genera SOLO si no vino una. Nunca se deriva del
	// usuario: el nombre es público en la red y una clave derivada de él
	// sería una cuenta regalada.
	generada := false
	password := strings.TrimSpace(params.Password)
	if password == "" {
		password = soulseek.GenerarPassword()
		if password == "" {
			return jsonErrorString("no se pudo generar una contraseña segura (falta entropía)")
		}
		generada = true
	}

	cliente.SetSettings(map[string]string{"usuario": usuario, "password": password})
	conectado, err := cliente.ProbarCredenciales()
	if err != nil {
		return jsonErrorSoulseek(err)
	}

	mensaje := "Cuenta conectada y lista para buscar en la red."
	if generada {
		mensaje = "Cuenta creada y conectada. La contraseña quedó guardada: " +
			"Soulseek no tiene recuperación, así que exportala si querés usar esta cuenta en otro cliente."
	}
	respuesta := map[string]interface{}{
		"ok":                true,
		"usuario":           conectado,
		"password":          password,
		"password_generada": generada,
		"mensaje":           mensaje,
	}
	data, err := json.Marshal(respuesta)
	if err != nil {
		return jsonError(err)
	}
	return string(data)
}

// motivoSoulseek clasifica el error en algo que la UI pueda ACCIONAR.
//
// El setup lo necesita: si el nombre ya está tomado, el usuario puede elegir
// otro y seguir; si el servidor está caído o no hay internet, no hay nada que
// el usuario pueda hacer y el setup no debe frenarse por eso.
func motivoSoulseek(err error) string {
	switch {
	case errors.Is(err, soulseek.ErrNombreTomado):
		return "nombre_tomado"
	case errors.Is(err, soulseek.ErrNombreInvalido):
		return "nombre_invalido"
	}
	return ""
}

// jsonErrorSoulseek devuelve {ok:false, motivo, error}. El motivo solo viaja
// cuando existe: así la UI no tiene que interpretar el texto para decidir si
// le pide al usuario que cambie el nombre o si simplemente avisa que falló.
func jsonErrorSoulseek(err error) string {
	respuesta := map[string]interface{}{
		"ok":    false,
		"error": err.Error(),
	}
	if m := motivoSoulseek(err); m != "" {
		respuesta["motivo"] = m
	}
	data, mErr := json.Marshal(respuesta)
	if mErr != nil {
		return jsonError(err)
	}
	return string(data)
}

// clienteSoulseek trae el cliente ya registrado. Si no hay provider (backend
// sin inicializar) se avisa en vez de abrir una conexión suelta que después
// nadie podría reutilizar.
func clienteSoulseek() (*soulseek.Client, error) {
	if reg == nil {
		return nil, fmt.Errorf("el backend todavía no está inicializado")
	}
	p := reg.Get("soulseek")
	if p == nil {
		return nil, fmt.Errorf("el proveedor de Soulseek no está registrado")
	}
	cliente, ok := p.(*soulseek.Client)
	if !ok {
		return nil, fmt.Errorf("el proveedor de Soulseek no es del tipo esperado")
	}
	return cliente, nil
}
