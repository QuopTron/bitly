package provider

import (
	"fmt"
	"net/url"
	"strings"
)

// ============================================================================
// RESOLUCIÓN DE ENLACES COMPARTIDOS (handleUrl)
//
// Qué hace: resuelve un enlace de música (Spotify, YouTube, Deezer, Tidal...)
// a un ítem reproducible. Cada extensión implementa handleUrl(url) y declara
// en su manifest urlHandler.patterns QUÉ enlaces sabe resolver.
//
// Por qué existe: antes los enlaces llegaban a la app y se descartaban. Las
// extensiones SIEMPRE supieron resolverlos, pero nadie las llamaba.
//
// Se conecta con: el manifest (loader_all → SetURLPatterns) y el puente RPC
// (gobackend.ResolveUrl), que es quien elige la extensión y normaliza el
// resultado para Flutter.
// ============================================================================

// HandleUrl llama a la función handleUrl(url) de la extensión y devuelve el
// mapa crudo que ésta responde ({success, type, track, tracks, album, ...}).
//
// Devuelve (nil, nil) cuando el resultado viene vacío y un error cuando la
// extensión marca el enlace como inválido o falla la llamada. El error usa el
// mismo camino que el resto de llamadas, así que una extensión que falla
// repetidamente entra en cooldown igual que en búsqueda.
func (p *ExtensionProvider) HandleUrl(enlace string) (map[string]interface{}, error) {
	res, err := p.call("handleUrl", enlace)
	if err != nil {
		return nil, fmt.Errorf("ext %s handleUrl: %w", p.extID, err)
	}
	if res == nil {
		return nil, nil
	}
	m, ok := res.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("ext %s handleUrl: respuesta inesperada %T", p.extID, res)
	}
	// Varias extensiones devuelven {success:false, error:"..."} en vez de
	// lanzar. Se trata igual que un fallo para que el llamador pruebe otra.
	if okv, existe := m["success"].(bool); existe && !okv {
		if msg := getString(m, "error"); msg != "" {
			return nil, fmt.Errorf("ext %s: %s", p.extID, msg)
		}
		return nil, fmt.Errorf("ext %s: no pudo resolver el enlace", p.extID)
	}
	return m, nil
}

// PuedeResolverURL reporta si el enlace coincide con alguno de los patrones
// que la extensión declara en su manifest (urlHandler.patterns).
func (p *ExtensionProvider) PuedeResolverURL(enlace string) bool {
	for _, patron := range p.urlPatterns {
		if PatronCoincide(enlace, patron) {
			return true
		}
	}
	return false
}

// PatronCoincide compara un enlace con un patrón del manifest. Reconoce las
// tres formas que usan las extensiones:
//
//   - esquema con dos puntos: "spotify:", "tidal:"  → prefijo literal;
//   - host simple:            "open.spotify.com", "youtu.be" → host exacto o
//     subdominio ("spotify.com" también cubre "open.spotify.com");
//   - host + ruta:            "www.youtube.com/watch" → prefijo sobre host+ruta.
func PatronCoincide(enlace, patron string) bool {
	u := strings.ToLower(strings.TrimSpace(enlace))
	p := strings.ToLower(strings.TrimSpace(patron))
	if u == "" || p == "" {
		return false
	}
	// "spotify:track:..." no tiene host; se compara como esquema.
	if strings.HasSuffix(p, ":") {
		return strings.HasPrefix(u, p)
	}

	host, ruta := partirURL(u)
	if host == "" {
		return false
	}
	if strings.Contains(p, "/") {
		return strings.HasPrefix(host+ruta, p)
	}
	return host == p || strings.HasSuffix(host, "."+p)
}

// partirURL extrae host y ruta de un enlace. Acepta enlaces sin esquema
// ("open.spotify.com/track/x"), que es como a veces los pega el usuario.
func partirURL(raw string) (host, ruta string) {
	// url.Parse trata "host/ruta" (sin esquema) como una ruta suelta, así que
	// se le antepone https:// cuando no hay esquema reconocible.
	if !tieneEsquema(raw) {
		raw = "https://" + raw
	}
	u, err := url.Parse(raw)
	if err != nil {
		return "", ""
	}
	// Hostname() descarta el puerto (y los corchetes de IPv6), así que
	// "open.spotify.com:443" compara contra "open.spotify.com".
	return strings.TrimSuffix(u.Hostname(), "."), u.Path
}

// tieneEsquema detecta "http://", "bitly://" u otro esquema antes de los dos
// primeros puntos y barras.
func tieneEsquema(raw string) bool {
	i := strings.Index(raw, ":")
	if i <= 0 {
		return false
	}
	// "spotify:track:xxx" NO es un esquema utilizable por url.Parse como URL
	// con host, pero tampoco lo necesita: el match por esquema ya lo cubre.
	if strings.Contains(raw[:i], "/") {
		return false
	}
	return strings.HasPrefix(raw[i:], "://")
}
