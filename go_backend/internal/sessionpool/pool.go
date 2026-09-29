// ─────────────────────────────────────────────────────────────
// pool.go — Pool de credenciales de sesión (ARL, tokens de Tidal,
// cuentas de Qobuz).
//
// Qué problema resuelve: una credencial suelta se muere (se banea, se
// expira) y el usuario tiene que pegar otra a mano. Con un pool:
//   - se juntan VARIAS credenciales (las propias + fuentes que él
//     configure),
//   - se validan contra el servicio real antes de usarlas,
//   - si una falla, la extensión rota a la siguiente sola.
//
// Es genérico a propósito: cada plataforma aporta su EXTRACTOR (cómo
// reconocer sus credenciales en un texto) y su VALIDADOR (cómo saber si
// siguen vivas). El núcleo no sabe de Deezer, Tidal ni Qobuz.
//
// Qué NO hace: no cosecha credenciales de internet por su cuenta. No
// existe hoy ningún endpoint público estable que las sirva (el listado
// histórico terminó en bots de Telegram y en un sitio con Turnstile),
// así que las FUENTES las decide el usuario y este paquete solo las
// descarga, las parsea y las valida.
//
// Se conecta con: extensions_settings.go (se dispara al guardar los
// ajustes de una extensión) y las extensiones deezer/tidal-web/
// qobuz-web (reciben el pool ya validado para rotar en caliente).
// Parte del flujo: sesiones de fuente (descarga directa con cuenta).
// ─────────────────────────────────────────────────────────────

package sessionpool

import (
	"io"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"
)

// timeoutFuente limita cada descarga de fuente: una URL caída no puede
// retrasar el guardado de ajustes del usuario.
const timeoutFuente = 10 * time.Second

// concurrenciaValidacion es cuántas credenciales se validan A LA VEZ contra el
// servicio real.
//
// Por qué importa: validar es una llamada de red por credencial (hasta
// timeoutValidacion cada una). En serie, una fuente con 20 ARLs podía tardar
// minutos y dejar colgado el guardado de ajustes; con este tope el tiempo es
// ~(n/6) veces un timeout, sin abrirle 20 conexiones al mismo servicio.
const concurrenciaValidacion = 6

// maxValidaciones acota cuántas credenciales de las FUENTES se validan en una
// corrida. Una fuente hostil (o un HTML enorme) puede devolver cientos de
// candidatos: sin tope, el guardado de ajustes queda esperando por todos. Las
// que quedan afuera se cuentan en [Resultado.Omitidas] y el orden de
// preferencia hace que sobrevivan las primeras del documento.
const maxValidaciones = 30

// userAgent realista: algunos hosts rechazan clientes desconocidos.
const userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
	"AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

// paresRe reconoce pares "clave=valor" o "clave: valor" de credenciales
// (arl, token, access_token...) en HTML, markdown, JSON o texto plano.
var paresRe = regexp.MustCompile(
	`(?i)(?:user_auth_token|auth_token|access_token|tidal_?token|token|arl)["']?\s*[:=]\s*["']?([A-Za-z0-9._~+/=-]{16,})`)

// Resultado describe lo que salió de una corrida del pool.
type Resultado struct {
	// Usables son las credenciales que pasaron la validación, en orden
	// de preferencia (la propia del usuario va primero).
	Usables []string
	// Descartadas son las que respondieron inválidas (para que el
	// usuario sepa que la fuente murió).
	Descartadas int
	// FuentesCaidas son las URLs que no se pudieron descargar.
	FuentesCaidas []string
	// Omitidas son las candidatas que ni se probaron porque la corrida
	// ya había alcanzado [maxValidaciones]. No son "muertas": son
	// "no evaluadas", y por eso no se cuentan en Descartadas.
	Omitidas int
}

// Opciones parametriza una corrida del pool: de dónde sacar los
// candidatos y cómo saber si siguen vivos.
type Opciones struct {
	Propias []string
	Fuentes []string
	// Extraer reconoce las credenciales de esta plataforma en un texto.
	Extraer func(texto string) []string
	// Validar dice si una credencial sigue sirviendo. Se puede llamar en
	// PARALELO (varias goroutines a la vez), así que tiene que ser segura
	// de usar desde varios hilos (las de este paquete solo usan el
	// *http.Client, que lo es).
	Validar func(cliente *http.Client, credencial string) bool
}

// ConstruirPool arma el pool final.
//
// Orden de preferencia:
//  1. Las credenciales propias SIEMPRE primero: la cuenta del usuario
//     manda sobre cualquier fuente externa (y se respetan aunque la
//     validación no se pueda ejecutar, para no dejarle la app rota si
//     el servicio está caído).
//  2. Las que salgan de las fuentes configuradas, ya validadas.
//
// Una fuente que falla no aborta nada: se cuenta como caída y se sigue.
func ConstruirPool(cliente *http.Client, o Opciones) Resultado {
	if cliente == nil {
		cliente = &http.Client{Timeout: timeoutFuente}
	}
	extraer := o.Extraer
	if extraer == nil {
		extraer = ExtraerParesClaveValor
	}
	var res Resultado

	// 1) Candidatos: propias primero, después las fuentes.
	candidatos := append([]string(nil), o.Propias...)
	for _, urlFuente := range o.Fuentes {
		cuerpo, err := DescargarFuente(cliente, urlFuente)
		if err != nil {
			res.FuentesCaidas = append(res.FuentesCaidas, urlFuente)
			continue
		}
		candidatos = append(candidatos, extraer(cuerpo)...)
	}
	candidatos = unicos(candidatos)

	propiasSet := map[string]bool{}
	for _, p := range unicos(o.Propias) {
		propiasSet[p] = true
	}

	// 2) Qué se valida y qué no. Las propias del usuario pasan SIEMPRE (sin
	// gastar una llamada) y el resto entra en la cola de validación, en orden
	// de aparición y sin pasar el tope.
	usables := make([]bool, len(candidatos))
	omitidos := make([]bool, len(candidatos))
	aValidar := make([]int, 0, len(candidatos))
	for i, c := range candidatos {
		if propiasSet[c] || o.Validar == nil {
			usables[i] = true
			continue
		}
		if len(aValidar) >= maxValidaciones {
			omitidos[i] = true
			res.Omitidas++
			continue
		}
		aValidar = append(aValidar, i)
	}

	// 3) Validación en paralelo acotado.
	validarEnParalelo(cliente, o.Validar, candidatos, aValidar, usables)

	// 4) Resultado en el MISMO orden de los candidatos: la credencial propia
	// primero y, después, el orden en que aparecieron en las fuentes.
	for i, c := range candidatos {
		if omitidos[i] {
			continue
		}
		if usables[i] {
			res.Usables = append(res.Usables, c)
		} else {
			res.Descartadas++
		}
	}
	return res
}

// validarEnParalelo prueba todas las candidatas de [indices] con hasta
// [concurrenciaValidacion] goroutines a la vez y deja el veredicto de cada una
// en su posición de [usables].
//
// Cada goroutine escribe SOLO el índice que tomó de la cola, así que no hay
// estado compartido ni necesidad de candado (el orden del resultado no depende
// de quién termina primero: se arma después, recorriendo los candidatos).
func validarEnParalelo(cliente *http.Client, validar func(*http.Client, string) bool, candidatos []string, indices []int, usables []bool) {
	if len(indices) == 0 {
		return
	}
	trabajadores := concurrenciaValidacion
	if len(indices) < trabajadores {
		trabajadores = len(indices)
	}

	cola := make(chan int)
	var wg sync.WaitGroup
	for t := 0; t < trabajadores; t++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range cola {
				usables[i] = validar(cliente, candidatos[i])
			}
		}()
	}
	for _, i := range indices {
		cola <- i
	}
	close(cola)
	wg.Wait()
}

// ExtraerParesClaveValor es el extractor por defecto: saca los valores
// de pares tipo "token=..." de un texto cualquiera.
func ExtraerParesClaveValor(texto string) []string {
	matches := paresRe.FindAllStringSubmatch(texto, -1)
	salida := make([]string, 0, len(matches))
	for _, m := range matches {
		if len(m) > 1 {
			salida = append(salida, m[1])
		}
	}
	return unicos(salida)
}

// DescargarFuente trae el cuerpo de una URL. Es best-effort: devuelve
// error para que el llamador lo cuente como fuente caída y siga.
func DescargarFuente(cliente *http.Client, urlFuente string) (string, error) {
	if cliente == nil {
		cliente = &http.Client{Timeout: timeoutFuente}
	}
	req, err := http.NewRequest(http.MethodGet, urlFuente, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "*/*")
	resp, err := cliente.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return "", &ErrorFuente{URL: urlFuente, Codigo: resp.StatusCode}
	}
	// Tope defensivo: una fuente que devuelve un binario enorme no puede
	// arrastrar toda la memoria de la app.
	cuerpo, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return "", err
	}
	return string(cuerpo), nil
}

// ErrorFuente indica que una fuente respondió con error HTTP.
type ErrorFuente struct {
	URL    string
	Codigo int
}

func (e *ErrorFuente) Error() string {
	return "fuente " + e.URL + " respondió HTTP " + itoa(e.Codigo)
}

// SepararCredenciales parte un texto con credenciales separadas por
// coma, espacio o salto de línea (lo que el usuario pega a mano).
//
// El filtro de longitud es solo para que basura corta no entre: cada
// plataforma valida además su formato real (ver el wrapper ConstruirPool*).
func SepararCredenciales(texto string) []string {
	campos := strings.FieldsFunc(texto, func(r rune) bool {
		return r == ',' || r == '\n' || r == '\r' || r == '\t' || r == ' '
	})
	salida := make([]string, 0, len(campos))
	for _, c := range campos {
		c = strings.TrimSpace(c)
		if len(c) >= 8 {
			salida = append(salida, c)
		}
	}
	return unicos(salida)
}

// unicos elimina duplicados conservando el orden de aparición (el orden
// importa: la credencial propia del usuario debe quedar primero).
func unicos(valores []string) []string {
	vistos := map[string]bool{}
	salida := make([]string, 0, len(valores))
	for _, v := range valores {
		v = strings.TrimSpace(v)
		if v == "" || vistos[v] {
			continue
		}
		vistos[v] = true
		salida = append(salida, v)
	}
	return salida
}

// itoa evita importar strconv solo para un entero.
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
