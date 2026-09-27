// client_test.go — Fija el contrato del resolvedor de identidad: resuelve el
// ISRC y los ids de Qobuz/TIDAL por HTTP, combina los dos catálogos y NUNCA
// entrega audio.
package flacdownloader

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

const (
	isrcPedido  = "USUG12607940"
	cuerpoQobuz = `{"tracks":[
		{"album":"NO ME ARREPIENTO","artist":"KAROL G","durationMs":225000,"id":441724687,
		 "isrc":"USUG12607940","title":"BbY WOW","url":"https://open.qobuz.com/track/441724687"},
		{"album":"Otra","artist":"Nadie","durationMs":100000,"id":1,
		 "isrc":"ZZZZ00000001","title":"BbY WOW","url":"https://open.qobuz.com/track/1"}
	]}`
	cuerpoTidal = `{"tracks":[
		{"album":"NO ME ARREPIENTO","artist":"KAROL G","durationMs":226000,"id":549980035,
		 "isrc":"USUG12607940","title":"BbY WOW","url":"https://tidal.com/browse/track/549980035"},
		{"album":"Solo Tidal","artist":"Otro","durationMs":200000,"id":999,
		 "isrc":"AAAA00000009","title":"Tema Solo Tidal","url":"https://tidal.com/browse/track/999"}
	]}`
)

// servidor arma un doble del servicio que responde por ruta.
func servidor(t *testing.T, respuestas map[string]string, estado int) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if estado != http.StatusOK {
			w.WriteHeader(estado)
			return
		}
		cuerpo, ok := respuestas[r.URL.Path]
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(cuerpo))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestGetTrackByISRCResuelveElTrack(t *testing.T) {
	srv := servidor(t, map[string]string{"/api/qobuz/search": cuerpoQobuz}, http.StatusOK)
	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	tr, err := c.GetTrackByISRC(isrcPedido)
	if err != nil {
		t.Fatalf("no debería fallar: %v", err)
	}
	if tr == nil {
		t.Fatal("debería resolver el ISRC")
	}
	if tr.ISRC != isrcPedido || tr.Title != "BbY WOW" || tr.Duration != 225000 {
		t.Fatalf("track mal resuelto: %+v", tr)
	}
	// El id de Qobuz habilita el CheckAvailability de la extensión sin buscar.
	if tr.QobuzID != "441724687" {
		t.Errorf("QobuzID = %q, se esperaba el id numérico", tr.QobuzID)
	}
	if tr.ID != isrcPedido {
		t.Errorf("ID = %q; con ISRC conocido la identidad es el ISRC", tr.ID)
	}
	if tr.Provider != name {
		t.Errorf("Provider = %q", tr.Provider)
	}
}

func TestGetTrackByISRCRechazaISRCDistinto(t *testing.T) {
	// La búsqueda devuelve resultados aproximados: solo vale el que DECLARA el
	// ISRC pedido.
	srv := servidor(t, map[string]string{"/api/qobuz/search": `{"tracks":[
		{"album":"Otra","artist":"Nadie","durationMs":100000,"id":1,
		 "isrc":"ZZZZ00000001","title":"BbY WOW","url":"https://open.qobuz.com/track/1"}
	]}`}, http.StatusOK)
	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	if tr, err := c.GetTrackByISRC(isrcPedido); err != nil || tr != nil {
		t.Fatalf("no debería aceptar un resultado sin el ISRC pedido: %+v (%v)", tr, err)
	}
}

func TestSearchTracksCombinaQobuzYTidalYDeduplica(t *testing.T) {
	srv := servidor(t, map[string]string{
		"/api/qobuz/search": cuerpoQobuz,
		"/api/tidal/search": cuerpoTidal,
	}, http.StatusOK)
	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	got, err := c.SearchTracks("BbY WOW KAROL G", 10)
	if err != nil {
		t.Fatalf("no debería fallar: %v", err)
	}
	// 4 resultados pero dos comparten ISRC → 3 únicos.
	if len(got) != 3 {
		t.Fatalf("esperaba 3 resultados únicos, hubo %d: %+v", len(got), got)
	}
	// El primero es el de Qobuz (orden Qobuz→TIDAL) y trae su id.
	if got[0].QobuzID != "441724687" || got[0].ISRC != isrcPedido {
		t.Fatalf("el primero debería ser el de Qobuz: %+v", got[0])
	}
	// El resultado que solo vive en TIDAL trae TidalID.
	var vistoTidal bool
	for _, tr := range got {
		if tr.TidalID == "999" {
			vistoTidal = true
		}
	}
	if !vistoTidal {
		t.Fatalf("faltó el resultado exclusivo de TIDAL: %+v", got)
	}
}

func TestSearchTracksRespetaElLimite(t *testing.T) {
	srv := servidor(t, map[string]string{
		"/api/qobuz/search": cuerpoQobuz,
		"/api/tidal/search": cuerpoTidal,
	}, http.StatusOK)
	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	got, _ := c.SearchTracks("BbY WOW", 1)
	if len(got) != 1 {
		t.Fatalf("con limit=1 debe devolver 1, hubo %d", len(got))
	}
}

func TestServicioCaidoNoRompeLaBusqueda(t *testing.T) {
	srv := servidor(t, nil, http.StatusInternalServerError)
	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	got, err := c.SearchTracks("BbY WOW", 5)
	if err != nil {
		t.Fatalf("un servicio caído no debe propagar error en la búsqueda: %v", err)
	}
	if len(got) != 0 {
		t.Fatalf("sin servicio no hay resultados: %+v", got)
	}
	if tr, err := c.GetTrackByISRC(isrcPedido); err == nil {
		t.Fatalf("GetTrackByISRC sí reporta el fallo: %+v", tr)
	}
}

func TestGetStreamURLNoEntregaAudio(t *testing.T) {
	c := NewClient(nil)
	if u, err := c.GetStreamURL(isrcPedido, "flac"); err == nil || u != "" {
		t.Fatalf("no puede entregar stream: %q (%v)", u, err)
	}
}

// El JSON real del servicio usa el mismo esquema de nombres para Qobuz y TIDAL;
// este test fija que el mapeo no se rompa si aparece un campo nuevo.
func TestEsquemaRealSeDecodifica(t *testing.T) {
	var resp respuestaBusqueda
	if err := json.Unmarshal([]byte(cuerpoQobuz), &resp); err != nil {
		t.Fatalf("no se pudo decodificar: %v", err)
	}
	if len(resp.Tracks) != 2 || resp.Tracks[0].ID != 441724687 {
		t.Fatalf("esquema inesperado: %+v", resp.Tracks)
	}
	if !strings.Contains(resp.Tracks[0].URL, "qobuz.com") {
		t.Fatalf("URL inesperada: %q", resp.Tracks[0].URL)
	}
}
