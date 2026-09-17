package lastfm

import "testing"

// Fila REAL de una tabla de pistas del sitio (recortada a lo que se analiza).
// Es la forma exacta que devuelve https://www.last.fm/music/<artista>/<álbum>:
// el video oficial va ANTES del nombre dentro de la fila.
const filaReal = `
<tr class="chartlist-row js-focus-controls-container" data-scrobble-row itemprop="track">
  <td class="chartlist-play">
    <a class="chartlist-play-button js-playlink"
       href="https://www.youtube.com/watch?v=%s"
       data-youtube-id="%s"
       data-youtube-url="https://www.youtube.com/watch?v=%s"
       data-track-name="%s"
       data-artist-name="%s"
       title="Play on YouTube">Play track</a>
  </td>
  <td class="chartlist-name"><a href="/music/x/_/y">%s</a></td>
  <td class="chartlist-artist"><a href="/music/x">%s</a></td>
  <td class="chartlist-duration">%s</td>
</tr>`

func htmlDeAlbum() string {
	// Los tres primeros temas reales del álbum "DeBÍ TiRAR MáS FOToS".
	filas := []struct{ yt, nombre, artista, dur string }{
		{"KU5V5WZVcVE", "NUEVAYoL", "Bad Bunny", "3:02"},
		{"Cpee1--hKCc", "PERFuMITO NUEVO", "Bad Bunny &amp; RaiNao", "3:20"},
		{"yIQ2VtGPt_E", "VeLDÁ", "Bad Bunny, Omar Courtz &amp; Dei V", "3:55"},
	}
	cuerpo := "<html><body><table>"
	for _, f := range filas {
		cuerpo += sprintfFila(f.yt, f.nombre, f.artista, f.dur)
	}
	return cuerpo + "</table></body></html>"
}

func sprintfFila(yt, nombre, artista, dur string) string {
	reemplazos := []string{yt, yt, yt, nombre, artista, nombre, artista, dur}
	salida := filaReal
	for _, r := range reemplazos {
		salida = reemplazaPrimero(salida, "%s", r)
	}
	return salida
}

func TestPistasDeTabla_OrdenDuracionesYVideoCorrecto(t *testing.T) {
	pistas := pistasDeTabla(htmlDeAlbum())
	if len(pistas) != 3 {
		t.Fatalf("se esperaban 3 pistas, llegaron %d", len(pistas))
	}
	esperado := []Pista{
		{Nombre: "NUEVAYoL", Artistas: "Bad Bunny", DuracionMs: 182000, YouTubeID: "KU5V5WZVcVE"},
		{Nombre: "PERFuMITO NUEVO", Artistas: "Bad Bunny & RaiNao", DuracionMs: 200000, YouTubeID: "Cpee1--hKCc"},
		{Nombre: "VeLDÁ", Artistas: "Bad Bunny, Omar Courtz & Dei V", DuracionMs: 235000, YouTubeID: "yIQ2VtGPt_E"},
	}
	for i, e := range esperado {
		if pistas[i] != e {
			t.Errorf("pista %d:\n  esperado %+v\n  llegó    %+v", i+1, e, pistas[i])
		}
	}
}

// Regresión del bug real: el primer intento emparejaba por "el próximo
// data-youtube-id de la página", y como el video viene ANTES del nombre, cada
// pista quedaba con el video de la SIGUIENTE (y la última sin video).
func TestPistasDeTabla_NoCorreLosVideosUnLugar(t *testing.T) {
	pistas := pistasDeTabla(htmlDeAlbum())
	if pistas[0].YouTubeID == "Cpee1--hKCc" {
		t.Fatal("la primera pista se quedó con el video de la segunda")
	}
	if pistas[2].YouTubeID == "" {
		t.Fatal("la última pista se quedó sin video")
	}
}

func TestDuracionAMs(t *testing.T) {
	casos := map[string]int{
		"3:02": 182000, "6:00": 360000, "1:02:03": 3723000, "": 0, "x": 0,
	}
	for entrada, esperado := range casos {
		if got := duracionAMs(entrada); got != esperado {
			t.Errorf("duracionAMs(%q) = %d, se esperaba %d", entrada, got, esperado)
		}
	}
}

func TestElegirPista_VerificaNombreYDuracion(t *testing.T) {
	pistas := []Pista{
		{Nombre: "NUEVAYoL", DuracionMs: 182000, YouTubeID: "KU5V5WZVcVE"},
		{Nombre: "NUevayol (Live)", DuracionMs: 300000, YouTubeID: "OOOOOOOOOOO"},
	}
	// El nombre se compara normalizado (mayúsculas, acentos y puntuación).
	if p := elegirPista(pistas, "nuevayol", 183000); p == nil || p.YouTubeID != "KU5V5WZVcVE" {
		t.Fatalf("no eligió la pista correcta: %+v", p)
	}
	// Duración que no corresponde: se descarta en vez de devolver otra cosa.
	if p := elegirPista(pistas, "NUEVAYoL", 260000); p != nil {
		t.Fatalf("aceptó una duración fuera de tolerancia: %+v", p)
	}
	// Pista sin video oficial: no sirve para pedir el stream.
	if p := elegirPista([]Pista{{Nombre: "DtMF"}}, "DtMF", 0); p != nil {
		t.Fatalf("devolvió una pista sin video: %+v", p)
	}
}

func TestGenerosDe(t *testing.T) {
	cuerpo := `<a href="/tag/reggaeton">reggaeton</a><a href="/tag/trap+latino">trap latino</a>
	<a href="/tag/reggaeton">reggaeton</a>`
	generos := generosDe(cuerpo)
	if len(generos) != 2 || generos[0] != "reggaeton" || generos[1] != "trap latino" {
		t.Fatalf("géneros inesperados: %v", generos)
	}
}

// reemplazaPrimero sustituye la primera aparición de "%s" (evita depender de
// fmt en un test de análisis puro).
func reemplazaPrimero(texto, marca, valor string) string {
	for i := 0; i+len(marca) <= len(texto); i++ {
		if texto[i:i+len(marca)] == marca {
			return texto[:i] + valor + texto[i+len(marca):]
		}
	}
	return texto
}
