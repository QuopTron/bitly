package download

import (
	"fmt"
	"strings"
)

// maxFallosEnMensaje es cuántos motivos de proveedor se listan en el mensaje
// final. El texto viaja al aviso de descarga de la app, así que no crece sin
// límite: el resto se cuenta.
const maxFallosEnMensaje = 3

// maxLargoMotivo acota cada motivo individual (algunos errores de extensión
// traen URLs o JSON largos que no aportan nada en pantalla).
const maxLargoMotivo = 140

// finalResult construye el Result de fallo con la clasificación final del
// error (verificación requerida gana sobre errores genéricos).
func (st *fallbackState) finalResult(itemID string) *Result {
	if st.encryptedSeen {
		st.lastErr = "solo stream encriptado no reproducible en todos los providers"
	}
	errType := clasificarErrorVerificacion(st.lastErr)
	if errType == "" && esFalloEscrituraAlmacenamiento(st.lastErr) {
		errType = "storage_write_failure"
	}
	// Un proveedor tiene la canción pero necesita su sesión firmada / cloudflare
	// challenge completado. Eso es más accionable que "fallaron todos": al
	// completar la verificación la canción suena. Se surface como
	// verification_required con el servicio correcto para que el cliente abra
	// el modal de ESE proveedor.
	if st.verificationSeen && errType == "" {
		errType = "verification_required"
		st.lastErr = "verificacion requerida en " + st.verificationService
	}
	// Sin clasificación específica, el mensaje enumera en QUÉ falló cada fuente
	// (red, DRM, sin stream, archivo descartado). Antes llegaba solo el último
	// error —o incluso el genérico "all providers failed"— y el usuario veía una
	// canción en rojo sin ninguna pista, igual que el log.
	if errType == "" {
		if resumen := resumenFallos(st.fallosPorProveedor); resumen != "" {
			st.lastErr = resumen
		}
	}
	if strings.TrimSpace(st.lastErr) == "" {
		st.lastErr = "ningun proveedor entrego un archivo reproducible"
	}
	return &Result{
		ItemID:    itemID,
		Success:   false,
		Provider:  st.verificationService,
		Error:     st.lastErr,
		ErrorType: errType,
		Service:   st.verificationService,
	}
}

// resumenFallos arma "proveedor: motivo; proveedor: motivo (+n)" para el
// mensaje final, recortando cada motivo y contando los que no entran.
func resumenFallos(fallos []string) string {
	if len(fallos) == 0 {
		return ""
	}
	usados := fallos
	resto := 0
	if len(fallos) > maxFallosEnMensaje {
		usados = fallos[:maxFallosEnMensaje]
		resto = len(fallos) - maxFallosEnMensaje
	}
	limpios := make([]string, 0, len(usados))
	for _, f := range usados {
		limpios = append(limpios, acortarMotivo(f))
	}
	resumen := strings.Join(limpios, "; ")
	if resto > 0 {
		resumen += fmt.Sprintf(" (+%d mas)", resto)
	}
	return resumen
}

// acortarMotivo recorta un motivo largo y colapsa los saltos de línea para que
// quepa en una sola línea de log y en el aviso de la app.
func acortarMotivo(motivo string) string {
	m := strings.Join(strings.Fields(motivo), " ")
	if len(m) <= maxLargoMotivo {
		return m
	}
	return m[:maxLargoMotivo] + "…"
}
