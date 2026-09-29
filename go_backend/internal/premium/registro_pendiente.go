// registro_pendiente.go — Cola de "marcar como usado" que quedó pendiente.
//
// Por qué existe: el registro vive en tu Worker, y un Worker (o la conexión)
// puede no estar disponible en el momento exacto en que alguien activa su
// código. Antes, con el token dentro de la app, ese caso era un error y el
// usuario no podía activar NADA. La regla ahora es la contraria:
//
//	· la activación NUNCA depende del registro (la firma ya se validó local);
//	· el "usado" se anota en este archivo y se reintenta después, así el
//	  registro queda al día sin que nadie tenga que hacer nada.
//
// El archivo vive en la carpeta de datos del equipo (misma idea que
// dirDatosBin/dirExtensiones del backend): BITLY_PREMIUM_DIR si está seteada,
// y si no, `os.UserConfigDir()/bitly/premium`.
package premium

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

const (
	archivoUsadosPendientes = "usados-pendientes.json"
	// Tope de la cola: es un registro de cortesía, no una base de datos. Si se
	// llena, se descartan los más viejos (los códigos ya activados siguen
	// activados igual: esto solo afecta al control de reuso).
	maxUsadosPendientes = 200
)

// pendientesMu protege el archivo. OJO: usadosPendientes() lo toma; las
// funciones que ya lo tomaron NO pueden llamarla (el mutex de Go no es
// reentrante y se cuelga para siempre) — usan leerUsadosPendientesSinLock.
var pendientesMu sync.Mutex

// dirDatosPremium resuelve una carpeta escribible, portable entre escritorio y
// móvil (en Android el cwd es "/" y no se puede escribir).
func dirDatosPremium() string {
	if d := strings.TrimSpace(os.Getenv("BITLY_PREMIUM_DIR")); d != "" {
		return d
	}
	if d, err := os.UserConfigDir(); err == nil && d != "" {
		return filepath.Join(d, "bitly", "premium")
	}
	return "bitly_premium"
}

func rutaUsadosPendientes() string {
	return filepath.Join(dirDatosPremium(), archivoUsadosPendientes)
}

// leerUsadosPendientesSinLock lee la cola del disco SIN tomar el mutex: quien
// llama ya lo tiene. Devuelve lista vacía si no hay nada o si el archivo quedó
// ilegible (nunca es un error para el usuario).
func leerUsadosPendientesSinLock() []string {
	crudo, err := os.ReadFile(rutaUsadosPendientes())
	if err != nil {
		return []string{}
	}
	var lista []string
	if err := json.Unmarshal(crudo, &lista); err != nil {
		return []string{}
	}
	return lista
}

// usadosPendientes devuelve la cola actual.
func usadosPendientes() []string {
	pendientesMu.Lock()
	defer pendientesMu.Unlock()
	return leerUsadosPendientesSinLock()
}

// guardarUsadosPendientesSinLock escribe la cola completa (atómica: temporal +
// rename, así un corte en el medio no deja un JSON roto). Tampoco toma el mutex.
func guardarUsadosPendientesSinLock(lista []string) {
	ruta := rutaUsadosPendientes()
	if err := os.MkdirAll(filepath.Dir(ruta), 0o755); err != nil {
		return
	}
	crudo, err := json.Marshal(lista)
	if err != nil {
		return
	}
	temporal := ruta + ".tmp"
	if err := os.WriteFile(temporal, crudo, 0o600); err != nil {
		return
	}
	_ = os.Rename(temporal, ruta)
}

// encolarUsadoPendiente anota un código para marcar como usado más tarde. No
// duplica y respeta el tope.
func encolarUsadoPendiente(code string) {
	code = strings.TrimSpace(code)
	if code == "" {
		return
	}
	pendientesMu.Lock()
	defer pendientesMu.Unlock()

	lista := leerUsadosPendientesSinLock()
	for _, c := range lista {
		if c == code {
			return
		}
	}
	lista = append(lista, code)
	if len(lista) > maxUsadosPendientes {
		lista = lista[len(lista)-maxUsadosPendientes:]
	}
	guardarUsadosPendientesSinLock(lista)
}

// quitarUsadoPendiente saca un código ya marcado.
func quitarUsadoPendiente(code string) {
	pendientesMu.Lock()
	defer pendientesMu.Unlock()

	lista := leerUsadosPendientesSinLock()
	resto := make([]string, 0, len(lista))
	for _, c := range lista {
		if c != code {
			resto = append(resto, c)
		}
	}
	guardarUsadosPendientesSinLock(resto)
}

// UsadosPendientesCuenta informa cuántos marcados quedaron pendientes (para el
// estado/log del backend y para las pruebas).
func UsadosPendientesCuenta() int {
	return len(usadosPendientes())
}
