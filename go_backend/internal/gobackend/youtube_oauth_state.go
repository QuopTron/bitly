package gobackend

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// =========================================================================
// YOUTUBE OAUTH (inicio de sesion con cuenta de Google para InnerTube)
// =========================================================================
//
// Flujo (no invasivo, el token nunca sale del dispositivo salvo hacia Google):
//  1. StartYoutubeOauth  — abre un listener loopback 127.0.0.1, genera el
//     verifier/state PKCE y devuelve la URL de consentimiento de Google.
//     El lado Dart la abre en el navegador del sistema; el usuario inicia
//     sesion en la pagina de Google.
//  2. Google redirige el navegador a http://127.0.0.1:PORT/?code=...&state=...
//     que atiende el listener en-proceso (mismo truco que el proxy local de
//     streaming, asi funciona en Android donde Chrome puede alcanzar el
//     loopback del dispositivo).
//  3. PollYoutubeOauth    — devuelve el code capturado una vez que el
//     navegador fue redirigido de vuelta.
//  4. ExchangeYoutubeOauth— cambia el code por tokens access + refresh via
//     oauth2.googleapis.com (PKCE: code_verifier del paso 1).
//  5. RefreshYoutubeOauth — renueva un access token guardado cuando hace falta.
//
// Todo el estado es solo en memoria; el client id/secret se pasan por llamada
// el aplicación's own settings storage, nunca logged.
var (
	ytOauthMu sync.Mutex

	ytOauthServer   *http.Server
	ytOauthCode     string
	ytOauthErr      string
	ytOauthState    string
	ytOauthVerifier string
	ytOauthClientID string
	ytOauthSecret   string
	ytOauthRedirect string
)

func urlAleatoria(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("r%d", time.Now().UnixNano())
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func challengePKCE(verifier string) string {
	sum := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(sum[:])
}

// youtubeOauthParams decodes {client_id, client_secret, scope} from the RPC
// payload. client_secret is optional for PKCE (desktop clients), but sending
// it makes the token endpoint accept the exchange even without PKCE support.
type youtubeOauthParams struct {
	ClientID     string `json:"client_id"`
	ClientSecret string `json:"client_secret"`
	Scope        string `json:"scope"`
}

// youtubeOauthParams decodes {client_id, client_secret, scope} from the RPC
// payload. client_secret is optional for PKCE (desktop clients), but sending
