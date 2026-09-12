package extensions

import (
	"fmt"
	"strings"
)

// parsedURL holds parsed URL components.
type parsedURL struct {
	href     string
	protocol string
	hostname string
	host     string
	port     string
	pathname string
	search   string
	hash     string
	origin   string
	params   map[string]string
}

func urlParse(rawURL string) (*parsedURL, error) {
	if rawURL == "" {
		return nil, fmt.Errorf("empty URL")
	}

	p := &parsedURL{params: make(map[string]string)}

	if idx := strings.Index(rawURL, "://"); idx >= 0 {
		// `protocol` sigue el ESTÁNDAR: solo el esquema con sus dos puntos
		// ("https:"), SIN las barras. Exponerlo como "https://" rompía a las
		// extensiones que lo comparan como lo compara el navegador:
		//   - amazon: /^https?:$/.test(protocol) -> false -> enlace descartado
		//     (return null: Amazon no resolvía NINGÚN enlace) y base = protocol
		//     + "//" + host quedaba "https:////host".
		//   - ytmusic: protocol !== "http:" -> proveedor de PO Token descartado
		//     (0 candidatos -> YouTube siempre en itag=18).
		// Las barras van en origin/href, que es donde el estándar las pone.
		p.protocol = rawURL[:idx+1]
		rawURL = rawURL[idx+3:]
	} else {
		p.protocol = "https:"
	}

	if idx := strings.Index(rawURL, "#"); idx >= 0 {
		p.hash = rawURL[idx:]
		rawURL = rawURL[:idx]
	}

	if idx := strings.Index(rawURL, "?"); idx >= 0 {
		p.search = rawURL[idx:]
		queryPart := rawURL[idx+1:]
		rawURL = rawURL[:idx]
		for _, pair := range strings.Split(queryPart, "&") {
			kv := strings.SplitN(pair, "=", 2)
			if len(kv) == 2 {
				p.params[kv[0]] = kv[1]
			}
		}
	}

	if idx := strings.Index(rawURL, "/"); idx >= 0 {
		p.hostname = rawURL[:idx]
		p.pathname = rawURL[idx:]
	} else {
		p.hostname = rawURL
		p.pathname = "/"
	}

	// hostname NO lleva el puerto (lo que las extensiones comparan contra
	// "youtu.be" o "open.spotify.com"); host sí lo lleva cuando existe.
	if idx := strings.Index(p.hostname, ":"); idx >= 0 {
		p.port = p.hostname[idx+1:]
		p.hostname = p.hostname[:idx]
	}
	p.host = p.hostname
	if p.port != "" {
		p.host += ":" + p.port
	}

	// origin SÍ lleva las barras: el esquema y "//" son parte del origen.
	p.origin = p.protocol + "//" + p.hostname
	if p.port != "" {
		p.origin += ":" + p.port
	}

	p.href = p.origin + p.pathname + p.search + p.hash
	return p, nil
}
