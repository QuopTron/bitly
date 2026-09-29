// registro_worker.go — El registro de códigos (confirmar + marcar usado) pasa
// por TU Worker, no por un token dentro de la app.
//
// Por qué: antes la app llevaba un PAT de GitHub COMPILADO ADENTRO
// (lib/config/secretos.dart → setPremiumGithubToken) para leer y escribir
// codes.json en el repo privado QuopTron/bitly_codes_premium. Ese token salía
// del APK con unzip + grep y era un token CLÁSICO (acceso a TODOS los repos de
// la cuenta). Ahora la app manda el código a tu Worker y el Worker hace el
// trabajo con el token guardado en SU entorno (secreto de Cloudflare, cifrado,
// nunca en el binario ni en el repo).
//
// La URL lleva el secreto en la ruta, así que se INYECTA EN EL BUILD igual que
// las del Worker de Qobuz (scripts/dev/qobuz_inyeccion.sh) y queda vacía en el
// repo, que es público:
//
//	-ldflags "-X github.com/zarz/bitly/go_backend/internal/premium.PremiumRegistroURLInyectada=https://<worker>/premium/<secreto>"
//
// Si no hay URL configurada, el registro simplemente no se consulta (como
// cuando no había token): los códigos firmados y los legacy siguen validando,
// porque la validación es local y no depende de ningún servidor.
package premium

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

// PremiumRegistroURLInyectada es la URL del registro en tu Worker, INYECTADA EN
// EL BUILD (ver arriba). Vacía en el repo A PROPÓSITO: la ruta lleva el secreto
// y este repositorio es público.
var PremiumRegistroURLInyectada = ""

// clienteRegistro es el cliente HTTP del registro. Timeout corto: la activación
// del código está esperando detrás, y sin registro igual se puede activar.
var clienteRegistro = &http.Client{Timeout: 8 * time.Second}

// premiumRegistroURL devuelve la URL configurada. La variable de entorno existe
// para las pruebas y para builds de diagnóstico sin recompilar.
func premiumRegistroURL() string {
	if v := strings.TrimSpace(os.Getenv("BITLY_PREMIUM_REGISTRO_URL")); v != "" {
		return strings.TrimRight(v, "/")
	}
	return strings.TrimRight(strings.TrimSpace(PremiumRegistroURLInyectada), "/")
}

// estadoAError traduce el estado que informa el registro al mismo ErrorPremium
// que usaba el camino directo de GitHub (la UI ya sabe traducir esos motivos).
//
// [firmado] importa para el caso "no está en el registro": un código FIRMADO no
// necesita estar anotado para ser legítimo — la firma ya lo prueba y nadie más
// que tu clave privada puede fabricar uno. Un código LEGACY, en cambio, puede
// falsificarse (su secreto viaja en el binario), así que ahí SÍ se exige que
// exista en el registro, como siempre.
func estadoAError(estado string, firmado bool) error {
	switch estado {
	case "activo":
		return nil
	case "usado":
		return nuevoError("codigo_usado", "Código ya usado")
	case "cancelado":
		return nuevoError("codigo_cancelado", "Código cancelado")
	case "libre":
		return nuevoError("codigo_liberado", "Código liberado")
	case "no_encontrado":
		if firmado {
			return nil
		}
		return nuevoError("codigo_no_encontrado", "Código no encontrado en el registro")
	case "":
		// Respuesta sin estado: el registro no confirmó nada. Si el código está
		// firmado, se acepta igual; si es legacy, se pide que exista (que es el
		// comportamiento de siempre).
		if firmado {
			return nil
		}
		return nuevoError("registro_no_verificado", "No se pudo verificar el código en el registro")
	default:
		return nuevoError("estado_desconocido", "Estado desconocido: "+estado)
	}
}

// respuestaRegistro es lo que devuelve el Worker.
type respuestaRegistro struct {
	Estado string `json:"estado"`
	Error  string `json:"error"`
}

// cuerpoRegistro es lo que se le manda: el código y si viene firmado (para que
// el Worker sepa si puede anotarlo solo cuando no está en el registro).
func cuerpoRegistro(code, id string) map[string]string {
	cuerpo := map[string]string{"code": code}
	if id != "" {
		cuerpo["id"] = id
	}
	if EsCodigoFirmado(code) {
		cuerpo["firmado"] = "true"
	}
	return cuerpo
}

// pedirAlRegistro hace el POST y devuelve el cuerpo ya parseado.
func pedirAlRegistro(url, accion string, cuerpo map[string]string) (*respuestaRegistro, error) {
	datos, err := json.Marshal(cuerpo)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequest(http.MethodPost, url+"/"+accion, bytes.NewReader(datos))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := clienteRegistro.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	crudo, err := io.ReadAll(io.LimitReader(resp.Body, 64*1024))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, nuevoError("registro_no_verificado", "No se pudo verificar el código en el registro")
	}
	var salida respuestaRegistro
	if err := json.Unmarshal(crudo, &salida); err != nil {
		return nil, nuevoError("registro_no_verificado", "No se pudo verificar el código en el registro")
	}
	return &salida, nil
}

// consultarRegistroWorker pregunta por el estado del código en tu Worker.
func consultarRegistroWorker(url, code, id string) (string, error) {
	salida, err := pedirAlRegistro(url, "verificar", cuerpoRegistro(code, id))
	if err != nil {
		return "", err
	}
	if salida.Error != "" {
		return "", nuevoError("registro_no_verificado", "No se pudo verificar el código en el registro")
	}
	return salida.Estado, nil
}

// marcarUsadoWorker le pide al Worker que marque el código como usado. El
// Worker es el que decide si puede anotarlo (solo si la firma verifica).
func marcarUsadoWorker(url, code string, firmado bool) error {
	cuerpo := map[string]string{"code": code}
	if firmado {
		cuerpo["firmado"] = "true"
	}
	_, err := pedirAlRegistro(url, "usar", cuerpo)
	return err
}

// ReintentarUsadosPendientes vuelve a mandar los "marcar usado" que quedaron
// pendientes cuando el Worker no respondía (o el equipo estaba sin internet).
//
// La llama el backend al ARRANCAR (y no durante la validación: cada reintento
// puede tardar segundos y nadie tiene que esperar eso para activar su código).
func ReintentarUsadosPendientes() {
	url := premiumRegistroURL()
	if url == "" {
		return
	}
	for _, code := range usadosPendientes() {
		if err := marcarUsadoWorker(url, code, EsCodigoFirmado(code)); err == nil {
			quitarUsadoPendiente(code)
		}
	}
}
