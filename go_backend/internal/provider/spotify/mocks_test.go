package spotify

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
)

type mockTransport struct {
	roundTrip func(req *http.Request) (*http.Response, error)
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return m.roundTrip(req)
}

// mockClient arma un cliente YA CONFIGURADO contra un servidor falso.
//
// Dos cosas que antes no hacía y ahora son obligatorias:
//
//   - Credenciales de mentira pero NO vacías: el cliente se niega a salir a la
//     red sin ellas (ver ensureToken), así que un test de búsqueda debe
//     simular un Spotify con claves puestas, que es el caso real.
//   - El endpoint de token lo sirve el propio mock. Varios tests devolvían la
//     misma respuesta para cualquier URL, incluida /api/token, y el cliente
//     aceptaba ese 200 sin access_token y seguía con un Bearer vacío. Eso ya
//     no pasa (una respuesta 2xx sin token es una respuesta rota), así que
//     cada test describe solo la API que está probando.
func mockClient(handler func(req *http.Request) (*http.Response, error)) *Client {
	return &Client{
		http: &http.Client{Transport: &mockTransport{roundTrip: func(req *http.Request) (*http.Response, error) {
			if strings.Contains(req.URL.String(), "/api/token") {
				return okJSON(map[string]interface{}{
					"access_token": "mock-token",
					"token_type":   "Bearer",
					"expires_in":   3600,
				}), nil
			}
			return handler(req)
		}}},
		clientID:     "cliente-de-prueba",
		clientSecret: "secreto-de-prueba",
	}
}

func okJSON(body interface{}) *http.Response {
	b, _ := json.Marshal(body)
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(string(b))),
		Header:     make(http.Header),
	}
}
