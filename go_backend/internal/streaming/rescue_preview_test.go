package streaming

import "testing"

// El guard existe por un bug real: un espejo/Archive devolvía un clip de 30s y
// la canción se cortaba. Estos tests fijan las dos reglas: (1) las URL de
// muestra se detectan por nombre, sin red y sin dudar; (2) el tamaño esperado
// se calcula con el piso del rango real, así una canción legítima nunca entra
// como "clip".

func TestEsURIPreviewDetectaMarcas(t *testing.T) {
	clips := []string{
		"https://cdn.example.com/sample/abc.flac",
		"https://cdn.example.com/abc_sample.flac",
		"https://cdn.example.com/preview/abc.mp3",
		"https://cdn.example.com/abc_30s.mp3",
		"https://cdn.example.com/stream?preview=1",
	}
	for _, u := range clips {
		if !EsURIPreview(u) {
			t.Errorf("%q debería reconocerse como clip", u)
		}
	}

	canciones := []string{
		"https://cdn.example.com/abc.flac",
		"https://ia801234.us.archive.org/12/items/disco/01_tema.flac",
		"https://googlevideo.com/videoplayback?id=abc&itag=251",
		"",
	}
	for _, u := range canciones {
		if EsURIPreview(u) {
			t.Errorf("%q NO es un clip y fue rechazada", u)
		}
	}
}

func TestTamanoEsperadoPorCalidad(t *testing.T) {
	// 3 minutos de audio.
	const tresMin = 180000

	flac := tamanoEsperadoBytes(tresMin, "FLAC")
	mp3_320 := tamanoEsperadoBytes(tresMin, "MP3_320")
	mp3_128 := tamanoEsperadoBytes(tresMin, "MP3_128")

	if !(flac > mp3_320 && mp3_320 > mp3_128) {
		t.Fatalf("los tamaños esperados deben bajar con la calidad: flac=%d 320=%d 128=%d",
			flac, mp3_320, mp3_128)
	}
	// Un clip de 30s de una canción de 3 min queda muy por debajo del umbral.
	clip := tamanoEsperadoBytes(30000, "FLAC")
	if float64(clip) >= float64(flac)*fraccionTamanoPreview {
		t.Fatalf("un clip de 30s no debería alcanzar el umbral: clip=%d total=%d", clip, flac)
	}
}

func TestEsPreviewStreamSinDuracionNoJuzga(t *testing.T) {
	// Sin duración de catálogo no hay con qué comparar: nunca se rechaza
	// (rechazar por las dudas haría bajar la canción completa sin motivo).
	if EsPreviewStream("https://cdn.example.com/abc.flac", "flac-rescue", 0, "FLAC") {
		t.Fatal("sin duración no debe declararse clip")
	}
	// Fuente que no puede devolver clips: se acepta sin sondear.
	if EsPreviewStream("https://cdn.example.com/abc.flac", "youtube", 200000, "FLAC") {
		t.Fatal("youtube no debe pasar por el guard de tamaño")
	}
}

func TestEsPreviewStreamURLMuertaNoBloquea(t *testing.T) {
	// Si el sondeo falla (URL inalcanzable) el candidato pasa: el guard solo
	// rechaza con evidencia, nunca por no haber podido medir.
	u := "http://127.0.0.1:1/abc.flac"
	if EsPreviewStream(u, "flac-rescue", 200000, "FLAC") {
		t.Fatal("una medición fallida no debe declarar clip")
	}
}
