// sync.go — Actualización SILENCIOSA de extensiones.
//
// El registro empaquetado (el `//go:embed` de este paquete) es la fuente de
// verdad de las extensiones: cada versión del binario trae la versión más
// nueva de cada extensión. Al arrancar, este archivo compara la versión
// empaquetada con la copia en disco y, si la instalada quedó VIEJA (o falta),
// reescribe la extensión completa en disco. Es best-effort y no reporta nada
// al usuario: las extensiones se mantienen al día solas.
//
// Se conecta con: exports_init_providers.go e extensions_system.go (llamadas
// al arranque) y con el loader de extensiones (loader_all.go).
// Parte del flujo: arranque del backend (registro de extensiones).
package bundled_extensions

import (
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// SincronizarConDisco actualiza en [destDir] las extensiones empaquetadas cuya
// versión instalada sea más vieja que la empaquetada (o que falten en disco).
// Devuelve los IDs actualizados. Nunca falla: cualquier error por extensión se
// ignora para no romper el arranque.
func SincronizarConDisco(destDir string) []string {
	if destDir == "" {
		return nil
	}
	dirs, err := List()
	if err != nil {
		return nil
	}
	var actualizadas []string
	for _, id := range dirs {
		ext, err := Load(id)
		if err != nil {
			continue
		}
		empaquetada := versionDeManifest(ext.ManifestData)
		if empaquetada == "" {
			empaquetada = "0.0.0"
		}
		instalada := versionEnDisco(filepath.Join(destDir, id, "manifest.json"))
		// Salvo cuando el empaquetado es más nuevo (o no hay copia en disco),
		// se deja intacta la extensión del usuario.
		if instalada != "" && !versionMasNueva(empaquetada, instalada) {
			continue
		}
		if err := escribirExtension(destDir, id); err != nil {
			continue
		}
		actualizadas = append(actualizadas, id)
	}
	return actualizadas
}

// escribirExtension copia TODOS los archivos de la extensión [id] del FS
// empaquetado a destDir/id, preservando subcarpetas.
func escribirExtension(destDir, id string) error {
	raiz := filepath.Join(destDir, id)
	if err := os.MkdirAll(raiz, 0o755); err != nil {
		return err
	}
	return fs.WalkDir(FS, id, func(ruta string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		data, err := fs.ReadFile(FS, ruta)
		if err != nil {
			return err
		}
		rel := strings.TrimPrefix(ruta, id+"/")
		destino := filepath.Join(raiz, filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(destino), 0o755); err != nil {
			return err
		}
		return os.WriteFile(destino, data, 0o644)
	})
}

// versionDeManifest lee el campo "version" del manifest empaquetado.
func versionDeManifest(manifest []byte) string {
	var m struct {
		Version string `json:"version"`
	}
	if err := json.Unmarshal(manifest, &m); err != nil {
		return ""
	}
	return strings.TrimSpace(m.Version)
}

// versionEnDisco lee la versión del manifest en disco ("" si no existe o no
// se puede parsear).
func versionEnDisco(rutaManifest string) string {
	data, err := os.ReadFile(rutaManifest)
	if err != nil {
		return ""
	}
	return versionDeManifest(data)
}

// versionMasNueva indica si [nueva] es mayor que [instalada] comparando por
// componentes numéricos (1.2.10 > 1.2.9). Si alguna no es numérica, se
// comparan como texto no vacío distinto.
func versionMasNueva(nueva, instalada string) bool {
	n, okN := partesVersion(nueva)
	i, okI := partesVersion(instalada)
	if !okN || !okI {
		return nueva != instalada
	}
	largo := len(n)
	if len(i) > largo {
		largo = len(i)
	}
	for k := 0; k < largo; k++ {
		var a, b int
		if k < len(n) {
			a = n[k]
		}
		if k < len(i) {
			b = i[k]
		}
		if a != b {
			return a > b
		}
	}
	return false
}

// partesVersion parte "1.2.3" (o "v1.2.3-beta") en números.
func partesVersion(v string) ([]int, bool) {
	v = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(v), "v"))
	if corte := strings.IndexAny(v, "-+"); corte >= 0 {
		v = v[:corte]
	}
	if v == "" {
		return nil, false
	}
	campos := strings.Split(v, ".")
	out := make([]int, 0, len(campos))
	for _, c := range campos {
		n, err := strconv.Atoi(strings.TrimSpace(c))
		if err != nil {
			return nil, false
		}
		out = append(out, n)
	}
	return out, true
}
