package streaming

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
)

// clasificarErrorStream decide si un error de stream aborta el intento o
// permite seguir con la siguiente calidad:
//   - descifrado cliente: aborta rapido SIN enfriar al proveedor (solo
//     download() puede servir esa cancion, deezer debe seguir usable).
//   - verificacion pendiente: la cancion EXISTE pero la sesion firmada debe
//     completarse primero — se devuelve ese veredicto sin enfriar, para que
//     el siguiente tap no omita la ruta rapida ni re-entre al walk de respaldo.
//   - cualquier otro error (429/bloqueo/gateway): enfria al proveedor y deja
//     que el llamador continue con la siguiente calidad.
//
// Devuelve (abort=true, err) cuando el intento del proveedor debe detenerse;
// si no, (abort=false, nil) para seguir sondeando la siguiente calidad.
func clasificarErrorStream(name, errMsg string) (bool, error) {
	if esErrorDescifradoCliente(errMsg) {
		return true, fmt.Errorf("stream de %s requiere descifrado cliente (solo download)", name)
	}
	if esErrorVerificacion(errMsg) {
		// Se enfria al proveedor con la ventana CORTA de verificacion en vez de
		// descongelarlo (MarkOk). Sin esto, tidal-web con sesion sin verificar
		// devuelve VERIFY_REQUIRED 6+ veces a lo largo de las fases de rescue,
		// quemando 3-5s en un fallo garantizado. El cooldown de 45s detiene el
		// martilleo y aun permite reintentar rapido si el usuario completa el modal.		cooldown.MarkError(name, errMsg)
		return true, &VerifyRequiredError{Service: name}
	}
	cooldown.MarkError(name, errMsg)
	return false, nil
}

// isVerificationError reports whether [errMsg] marks a signed-session /
// Cloudflare challenge (VERIFY_REQUIRED, "verification required", 428) rather
// than a definitive "track not available" — the track EXISTS, it just needs
// its session verified to play.
func esErrorVerificacion(errMsg string) bool {
	if errMsg == "" {
		return false
	}
	e := strings.ToLower(errMsg)
	for _, marker := range []string{
		"verify_required",
		"verify required",
		"verification required",
		"precondition required",
		"http 428",
		"status 428",
	} {
		if strings.Contains(e, marker) {
			return true
		}
	}
	return false
}
