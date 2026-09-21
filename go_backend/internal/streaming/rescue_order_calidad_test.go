// ─────────────────────────────────────────────────────────────
// rescue_order_calidad_test.go — Fija la prioridad que le da turno al
// canal que resuelve FLAC por ISRC (flac-rescue/arcod) cuando el usuario
// pidió sin pérdida, y que el orden histórico no cambie con pérdida.
//
// Por qué existe: el canal iba cuarto en la lista y, con dos turnos
// ocupados por los que streamean, se salteaba por falta de slot —
// medido en el emulador con "Tití Me Preguntó" (el catálogo lo tiene).
//
// Se conecta con: rescue_order.go (ordenProvidersStreamingCalidad,
// workersRescate) y play_fuentes_stream_test.go (armaRegistry).
// Parte del flujo: cadena de rescate de audio.
// ─────────────────────────────────────────────────────────────

package streaming

import "testing"

// TestOrdenSinPerdidaPoneElFLACPrimero: con "flac" las fuentes que pueden
// entregarlo EN VIVO van antes que los re-subidos; con "high" el orden es el
// histórico (nada cambia para quien no pidió sin pérdida).
func TestOrdenSinPerdidaPoneElFLACPrimero(t *testing.T) {
	reg, release := armaRegistry("muerta")
	defer close(release)

	historico := ordenProvidersStreaming(reg)
	conPerdida := ordenProvidersStreamingCalidad(reg, "high")
	if len(conPerdida) != len(historico) {
		t.Fatalf("con pérdida el orden cambió: %v vs %v", conPerdida, historico)
	}
	for i := range historico {
		if conPerdida[i] != historico[i] {
			t.Fatalf("con pérdida debe conservarse el orden histórico: %v vs %v",
				conPerdida, historico)
		}
	}

	sinPerdida := ordenProvidersStreamingCalidad(reg, "flac")
	if len(sinPerdida) != len(historico) {
		t.Fatalf("sin pérdida se perdieron fuentes: %v vs %v", sinPerdida, historico)
	}
	primerReSubido, ultimaLossless := len(sinPerdida), -1
	for i, n := range sinPerdida {
		if esFuenteLosslessSiempre(n) {
			ultimaLossless = i
			continue
		}
		if esProveedorReSubido(n) && i < primerReSubido {
			primerReSubido = i
		}
	}
	if ultimaLossless < 0 {
		t.Fatalf("sin pérdida no quedó ninguna fuente lossless: %v", sinPerdida)
	}
	if ultimaLossless > primerReSubido {
		t.Fatalf("sin pérdida el re-subido %q va antes que una fuente lossless: %v",
			sinPerdida[primerReSubido], sinPerdida)
	}
}

// TestWorkersRescateSumaTurnoSinPerdida: el turno extra es lo que evita que la
// fuente del FLAC espere a que un re-subido suelte el suyo. Con pérdida el
// paralelismo no sube (subirlo disparaba 429 y la tercera canción se quedaba
// sin stream).
func TestWorkersRescateSumaTurnoSinPerdida(t *testing.T) {
	if workersRescate("high") != 2 {
		t.Fatalf("con pérdida el paralelismo debe ser 2, no %d", workersRescate("high"))
	}
	if workersRescate("flac") <= workersRescate("high") {
		t.Fatalf("sin pérdida debe haber un turno extra: %d", workersRescate("flac"))
	}
	if workersRescate("") != workersRescate("high") {
		t.Fatalf("sin calidad declarada el paralelismo debe ser el de siempre")
	}
}
