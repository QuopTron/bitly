// dirs_permitidos_test.go — Fija QUÉ se puede escribir desde una extensión.
//
// Dos errores opuestos cuestan caro: negar la carpeta de descargas del usuario
// (toda descarga de extensión falla con "not in allowed directories", que fue
// el bug real) y aceptar de más (la whitelist dejaría de proteger nada). El
// borde que se prueba con más cuidado es el de las carpetas hermanas: un
// HasPrefix crudo aceptaría `/a/bc` como si estuviera dentro de `/a/b`.
//
// Se conecta con: dirs_permitidos.go + file_download.go (resolverRuta).
// Parte del flujo: descarga de audio/video/letras por extensiones.
package extensions

import (
	"path/filepath"
	"testing"
)

func TestResolverRutaAceptaCarpetaDeDescargas(t *testing.T) {
	descargas := t.TempDir()
	SetDirectoriosPermitidos([]string{descargas})
	defer SetDirectoriosPermitidos(nil)

	s := &Sandbox{Config: RuntimeConfig{AllowedDirs: []string{"."}}}
	destino := filepath.Join(descargas, "sub", "cancion.flac")
	if _, err := resolverRuta(s, destino); err != nil {
		t.Fatalf("la carpeta de descargas debía estar permitida: %v", err)
	}
}

func TestResolverRutaRechazaFueraDeLoPermitido(t *testing.T) {
	base := t.TempDir()
	SetDirectoriosPermitidos([]string{filepath.Join(base, "permitido")})
	defer SetDirectoriosPermitidos(nil)

	s := &Sandbox{Config: RuntimeConfig{AllowedDirs: []string{filepath.Join(base, "permitido")}}}
	// Carpeta HERMANA con el mismo prefijo textual: no debe colarse.
	if _, err := resolverRuta(s, filepath.Join(base, "permitido-falso", "x.flac")); err == nil {
		t.Fatal("una carpeta hermana con prefijo común no debe estar permitida")
	}
	if _, err := resolverRuta(s, filepath.Join(base, "otro", "x.flac")); err == nil {
		t.Fatal("una carpeta ajena no debe estar permitida")
	}
}

func TestDentroDeRutaRespetaElLimiteDeSeparador(t *testing.T) {
	base := filepath.Join(t.TempDir())
	casos := []struct {
		abs, dir string
		esperado bool
	}{
		{filepath.Join(base, "a", "b"), filepath.Join(base, "a"), true},
		{filepath.Join(base, "a"), filepath.Join(base, "a"), true},
		{filepath.Join(base, "ab"), filepath.Join(base, "a"), false},
	}
	for _, c := range casos {
		if got := dentroDeRuta(c.abs, c.dir); got != c.esperado {
			t.Errorf("dentroDeRuta(%q, %q) = %v, esperaba %v",
				c.abs, c.dir, got, c.esperado)
		}
	}
}

func TestSetDirectoriosPermitidosNormalizaYDescartaVacios(t *testing.T) {
	base := t.TempDir()
	SetDirectoriosPermitidos([]string{"", "  ", base, base})
	defer SetDirectoriosPermitidos(nil)

	dirs := DirectoriosPermitidos()
	if len(dirs) != 1 {
		t.Fatalf("esperaba 1 directorio (sin vacíos ni duplicados), hubo %d: %v",
			len(dirs), dirs)
	}
	if !filepath.IsAbs(dirs[0]) {
		t.Fatalf("la ruta debía quedar absoluta: %s", dirs[0])
	}
}
