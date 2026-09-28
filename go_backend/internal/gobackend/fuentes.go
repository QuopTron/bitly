package gobackend

// =========================================================================
// TIPOGRAFÍAS (Ajustes → Apariencia → Tipografía)
//
// La app trae UNA tipografía empaquetada (Google Sans Flex) y el resto se baja
// a pedido. El CATÁLOGO vive en Flutter a propósito: ahí están los nombres, el
// desbloqueo (horas/versión) y el respaldo sin red, y la UI los necesita
// aunque el backend no esté. Acá queda solo lo que Flutter no puede hacer:
// traer el archivo, validarlo y dejarlo en disco.
//
// Es el MISMO contrato que el caché de carátulas (SaveCover): Flutter manda la
// URL y recibe una RUTA LOCAL. La segunda vez que se pide la misma tipografía
// no hay red de por medio — el arranque con una tipografía ya bajada no cuesta
// nada.
// =========================================================================

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// FuentesDir es la carpeta donde quedan las tipografías descargadas.
//
// Cuelga del directorio de datos de la app (igual que "covers") y no de una
// ruta relativa: en Android el CWD es "/", que no es escribible, y la descarga
// habría fallado en silencio dejando la app con la tipografía de fábrica sin
// explicar por qué.
func FuentesDir() string {
	return filepath.Join(filepath.Dir(dirExtensiones()), "fuentes")
}

// DescargarFuente deja el .ttf de `url` en disco y devuelve su ruta ABSOLUTA.
//
// Contrato (espejo de SaveCover): devuelve "" cuando no se pudo. Flutter, ante
// un "", se queda con la tipografía empaquetada — la app nunca se rompe por
// una fuente que no bajó.
//
// Params: {id, url, sha256}
//
//	id     → nombre del archivo en disco (se valida: sólo [a-z0-9_])
//	url    → de dónde bajarla
//	sha256 → huella esperada ("" = no se verifica; alcanza con la firma sfnt)
func DescargarFuente(payload string) string {
	var params struct {
		ID     string `json:"id"`
		URL    string `json:"url"`
		SHA256 string `json:"sha256"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return ""
	}
	// El id termina siendo un NOMBRE DE ARCHIVO: si no se valida, un id con
	// "../" escribiría fuera de la carpeta de fuentes.
	if !idFuenteValido(params.ID) {
		return ""
	}
	path := filepath.Join(FuentesDir(), params.ID+".ttf")

	// Ya bajada: si está sana se devuelve sin tocar la red.
	if _, err := os.Stat(path); err == nil {
		if archivoFuenteSano(path, params.SHA256) {
			return absoluta(path)
		}
		// Rota, truncada o de otra versión: se descarta y se reintenta.
		_ = os.Remove(path)
	}

	if params.URL == "" {
		return ""
	}
	data, err := descargarFuenteBytes(params.URL)
	if err != nil {
		return ""
	}
	if !coincideSHA256(data, params.SHA256) {
		return ""
	}
	if err := os.MkdirAll(FuentesDir(), 0755); err != nil {
		return ""
	}
	if err := escribirAtomico(path, data); err != nil {
		return ""
	}
	return absoluta(path)
}

// BorrarFuentes vacía la carpeta de tipografías bajadas (Ajustes → Apariencia
// → Tipografía → liberar espacio). Después de esto la app vuelve a la
// empaquetada hasta que la vuelvan a pedir.
func BorrarFuentes() string {
	if err := os.RemoveAll(FuentesDir()); err != nil {
		return `{"ok":false}`
	}
	return `{"ok":true}`
}

// absoluta devuelve la ruta absoluta (la UI la usa como ruta de archivo local);
// si no se puede resolver, deja la que vino.
func absoluta(path string) string {
	if abs, err := filepath.Abs(path); err == nil {
		return abs
	}
	return path
}
