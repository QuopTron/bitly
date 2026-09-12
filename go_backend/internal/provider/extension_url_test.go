package provider

import "testing"

// ═══════════════════════════════════════════════════════════════════════
// Resolución de enlaces: elección de extensión por patrón del manifest
//
// Cubre las tres formas de patrón que declaran las extensiones (host,
// host+ruta y esquema) y los casos que antes rompían el enrutado: enlaces sin
// esquema, subdominios y enlaces de un host distinto que NO deben matchear.
// ═══════════════════════════════════════════════════════════════════════

func TestPatronCoincide(t *testing.T) {
	casos := []struct {
		nombre string
		enlace string
		patron string
		quiere bool
	}{
		{"host exacto", "https://open.spotify.com/track/abc", "open.spotify.com", true},
		{"subdominio por patrón raíz", "https://open.spotify.com/track/abc", "spotify.com", true},
		{"host con puerto", "https://open.spotify.com:443/track/abc", "open.spotify.com", true},
		{"host+ruta", "https://www.youtube.com/watch?v=xyz", "www.youtube.com/watch", true},
		{"host+ruta no coincide", "https://www.youtube.com/playlist?list=1", "www.youtube.com/watch", false},
		{"esquema spotify", "spotify:track:4cOdK2wGLETKBW3PvgPWqT", "spotify:", true},
		{"esquema ajeno", "tidal:track:123", "spotify:", false},
		{"short link youtu.be", "https://youtu.be/dQw4w9WgXcQ", "youtu.be", true},
		{"sin esquema", "open.spotify.com/album/1", "open.spotify.com", true},
		{"otro host no matchea", "https://deezer.com/track/1", "open.spotify.com", false},
		{"host parecido no matchea", "https://notspotify.com/track/1", "spotify.com", false},
		{"vacío", "", "spotify.com", false},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			if got := PatronCoincide(c.enlace, c.patron); got != c.quiere {
				t.Errorf("PatronCoincide(%q, %q) = %v, quiero %v", c.enlace, c.patron, got, c.quiere)
			}
		})
	}
}

// La extensión sólo se ofrece para los enlaces que declara en su manifest.
func TestPuedeResolverURLSoloSusPatrones(t *testing.T) {
	ep := NewExtensionProvider("spotify-web", "spotify-web", nil)
	ep.SetURLPatterns([]string{"open.spotify.com", "spotify.com", "spotify:"})

	if !ep.PuedeResolverURL("https://open.spotify.com/track/x") {
		t.Error("debería aceptar un enlace de Spotify")
	}
	if ep.PuedeResolverURL("https://music.youtube.com/watch?v=x") {
		t.Error("no debería aceptar un enlace de YouTube")
	}
	if ep.PuedeResolverURL("https://open.spotify.com/track/x") == false {
		t.Error("sin patrones declarados no debería aceptar nada")
	}

	sinPatrones := NewExtensionProvider("vacia", "vacia", nil)
	if sinPatrones.PuedeResolverURL("https://open.spotify.com/track/x") {
		t.Error("una extensión sin urlHandler no puede reclamar enlaces")
	}
}
