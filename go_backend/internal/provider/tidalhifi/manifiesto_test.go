package tidalhifi

// manifiesto_test.go — Fija la lectura del manifiesto DASH de Tidal y el
// desarmado del MP4 fragmentado. Los datos son RECORTES REALES de una
// respuesta de Tidal (mismo XML, mismos nombres de caja), no inventos: un
// manifiesto con otra forma es exactamente el fallo que hay que detectar.
//
// Nunca sale a la red.

import (
	"encoding/binary"
	"strings"
	"testing"
)

// mpdReal es un recorte del MPD que devuelve Tidal para una pista lossless:
// 45 segmentos de 176128 muestras a 44100 (≈4 s) y uno final más corto.
const mpdReal = `<?xml version='1.0' encoding='UTF-8'?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static" mediaPresentationDuration="PT3M3.685S">
<Period id="0"><AdaptationSet contentType="audio" mimeType="audio/mp4">
<Representation id="FLAC,44100,16" codecs="flac" bandwidth="930452" audioSamplingRate="44100">
<SegmentTemplate timescale="44100" startNumber="1" initialization="https://audio.tidal.com/init.mp4?sig=1&amp;x=2" media="https://audio.tidal.com/seg/$Number$.mp4?sig=1&amp;x=2">
<SegmentTimeline><S d="176128" r="44"/><S d="174770"/></SegmentTimeline>
</SegmentTemplate></Representation></AdaptationSet></Period></MPD>`

func TestAnalizarMPDArmaLosSegmentos(t *testing.T) {
	plan, err := analizarMPD(mpdReal, []string{"FLAC"}, "https://m.mp4")
	if err != nil {
		t.Fatalf("no debería fallar: %v", err)
	}
	if !strings.HasPrefix(plan.inicial, "https://audio.tidal.com/init.mp4") {
		t.Fatalf("inicial mal leído: %q", plan.inicial)
	}
	// Las entidades del XML (&amp;) tienen que quedar como &, o la firma del
	// CDN no valida y CADA segmento falla con 403.
	if strings.Contains(plan.inicial, "&amp;") {
		t.Fatalf("el inicial conserva entidades HTML: %q", plan.inicial)
	}
	// r=44 son 45 segmentos, más el último sin repeticiones.
	if len(plan.segmentos) != 46 {
		t.Fatalf("esperaba 46 segmentos, hubo %d", len(plan.segmentos))
	}
	if !strings.Contains(plan.segmentos[0], "/seg/1.mp4") {
		t.Fatalf("el primer segmento no es el 1: %q", plan.segmentos[0])
	}
	if !strings.Contains(plan.segmentos[45], "/seg/46.mp4") {
		t.Fatalf("el último segmento no es el 46: %q", plan.segmentos[45])
	}
	if !plan.esSinPerdida || plan.formato != "FLAC" {
		t.Fatalf("debería ser sin pérdida: %+v", plan)
	}
	if plan.durTotalMs != 183685 {
		t.Fatalf("duración mal leída del MPD: %d", plan.durTotalMs)
	}
}

func TestAnalizarMPDRechazaManifiestoSinPlantilla(t *testing.T) {
	if _, err := analizarMPD(`<MPD><Period/></MPD>`, nil, "u"); err == nil {
		t.Fatal("un manifiesto sin segmentos debe fallar, no devolver un plan vacío")
	}
}

func TestCalidadesAProbarDegradaSinPerdida(t *testing.T) {
	// Un pedido sin pérdida intenta sin pérdida y después degrada: quedarse
	// sin la canción por no tener FLAC es peor que bajarla en 320.
	if got := calidadesAProbar(""); len(got) < 2 || got[0] != "LOSSLESS" {
		t.Fatalf("cascada inesperada: %v", got)
	}
	if got := calidadesAProbar("HIGH"); len(got) != 1 || got[0] != "HIGH" {
		t.Fatalf("HIGH no debería probar sin pérdida: %v", got)
	}
}

// TestBloquesFLACDeExtraeLaMetadata arma un segmento inicial como los de
// Tidal (ftyp + moov > trak > mdia > minf > stbl > stsd > dfLa) y comprueba
// que se saquen los bloques FLAC tal cual.
func TestBloquesFLACDeExtraeLaMetadata(t *testing.T) {
	streaminfo := []byte{0x80, 0x00, 0x00, 0x22} // último + tipo 0 + 34 bytes
	streaminfo = append(streaminfo, make([]byte, 34)...)
	// STREAMINFO realista: 4096/4096, 44100 Hz, 2 canales, 16 bits, 8098721 muestras.
	binary.BigEndian.PutUint16(streaminfo[4:6], 4096)
	binary.BigEndian.PutUint16(streaminfo[6:8], 4096)
	empaquetado := uint64(44100)<<44 | uint64(1)<<41 | uint64(15)<<36 | uint64(8098721)
	binary.BigEndian.PutUint64(streaminfo[14:22], empaquetado)

	dfLa := caja("dfLa", append([]byte{0, 0, 0, 0}, streaminfo...))
	// Cadena de contenedores hasta dfLa, como en el archivo real.
	cuerpo := caja("stsd", dfLa)
	cuerpo = caja("stbl", cuerpo)
	cuerpo = caja("minf", cuerpo)
	cuerpo = caja("mdia", cuerpo)
	cuerpo = caja("trak", cuerpo)
	moov := caja("moov", cuerpo)
	inicial := append(caja("ftyp", []byte("iso8")), moov...)

	bloques, err := bloquesFLACDe(inicial)
	if err != nil {
		t.Fatalf("debería encontrar los bloques: %v", err)
	}
	if len(bloques) != len(streaminfo) {
		t.Fatalf("bloques mal extraídos: %d vs %d", len(bloques), len(streaminfo))
	}
	if bloques[0]&0x7F != 0 {
		t.Fatalf("el primer bloque debería ser STREAMINFO: %x", bloques[0])
	}
}

func TestBloquesFLACDeFallaSinDFLa(t *testing.T) {
	if _, err := bloquesFLACDe(caja("ftyp", []byte("iso8"))); err == nil {
		t.Fatal("sin dfLa no hay metadata FLAC: debe fallar en vez de armar un FLAC roto")
	}
}

func TestPayloadsMdatSacaElAudioDeCadaSegmento(t *testing.T) {
	audio1 := []byte{0xFF, 0xF8, 0xC9, 0xA8, 1, 2, 3}
	audio2 := []byte{0xFF, 0xF8, 0x11, 0x22}
	segmento := append(caja("moof", []byte("mfhd")), caja("mdat", audio1)...)
	segmento = append(segmento, caja("mdat", audio2)...)

	payloads := payloadsMdat(segmento)
	if len(payloads) != 2 {
		t.Fatalf("esperaba 2 mdat, hubo %d", len(payloads))
	}
	if string(payloads[0]) != string(audio1) || string(payloads[1]) != string(audio2) {
		t.Fatalf("payloads mal extraídos: %v", payloads)
	}
}

// caja arma una caja ISO-BMFF (tamaño + nombre + contenido).
func caja(nombre string, contenido []byte) []byte {
	salida := make([]byte, 8, 8+len(contenido))
	binary.BigEndian.PutUint32(salida, uint32(8+len(contenido)))
	copy(salida[4:], nombre)
	return append(salida, contenido...)
}
