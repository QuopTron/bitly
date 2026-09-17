// ─────────────────────────────────────────────────────────────
// compartido.go — Un solo cliente de Last.fm por proceso.
//
// Por qué: la caché y la pausa por desafío son por cliente. Si cada parte
// de la app armara el suyo, dos consultas simultáneas de la misma página
// gastarían dos peticiones y el sitio castigaría con el desafío. Con el
// compartido, la caché y las pausas son de todos.
// ─────────────────────────────────────────────────────────────

package lastfm

import "sync"

var (
	compartidoOnce sync.Once
	compartido     *Client
)
