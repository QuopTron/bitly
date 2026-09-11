package extensions

import (
	"encoding/json"
	"time"
)

func jsonUnmarshal(data []byte, v interface{}) error {
	return json.Unmarshal(data, v)
}

func marshalJSON(v interface{}) ([]byte, error) {
	return json.Marshal(v)
}

const signedSessionRefreshSkew = time.Hour

// Politica de keepalive de sesiones firmadas: mientras la app esta en primer
// plano, Flutter llama KeepAliveSignedSessions con un timer; el sandbox de
// cada fuente renueva su sesion silenciosamente cuando esta por expirar para
// que un token valido nunca muera a mitad de uso (lo que devolveria
// VERIFY_REQUIRED en el siguiente stream/busqueda/descarga). El refresco solo
// ocurre mientras el registro es usable — una sesion ya expirada o ausente no
// se toca: la app solo pide challenge humano ante una accion explicita.
const (
	// Una sesion con menos de este tiempo restante se renueva. El gateway
	// emite sesiones de vida corta (~1-2 min), asi que este lead se cumple
	// practicamente siempre y el pacing de abajo es quien manda.
	signedSessionKeepAliveLead = 5 * time.Minute
	// Nunca renovar la misma fuente mas seguido que esto (ritmo de gateway).
	// Debe quedar por debajo del TTL para alcanzar 2-3 refrescos por sesion.
	signedSessionKeepAliveMinInterval = 25 * time.Second
	// Tras un refresco fallido, esperar este tiempo antes de reintentar esa
	// fuente. Tiene que ser CORTO: si supera el TTL de la sesion, una unica
	// falla de red condena la sesion y obliga a un challenge humano.
	signedSessionKeepAliveBackoff = 20 * time.Second
	// Timeout HTTP por llamada de keepalive (no bloquear el hilo del bridge
	// con un endpoint muerto; el cliente compartido tiene default de 30s).
	signedSessionKeepAliveTimeout = 8 * time.Second
)

// bootstrapSignedSession calls GET /bootstrap?app_version&install_id.
// It either provisions a session silently or returns a challenge URL.
