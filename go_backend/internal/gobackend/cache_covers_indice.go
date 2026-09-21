package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// Índice de carátulas: .covers/index.json
//
// El archivo de portada se nombra con el hash de la URL (deduplica: la misma
// tapa compartida por 20 canciones es un solo archivo). Eso hacía que una
// carátula guardada por un LIKE no la encontrara una DESCARGA del mismo track
// (que busca por isrc/id/nombre) y viceversa: cada camino bajaba su copia o,
// peor, se quedaba sin nada.
//
// El índice guarda key → archivo para que cualquier camino recupere la
// portada que ya está en disco, sin red. Se guarda junto a las imágenes y se
// poda cuando la evicción borra un archivo.

const archivoIndicePortadas = "index.json"

var (
	muIndicePortadas sync.Mutex
	// indicePortadas cachea el mapa por directorio (los RPC llegan seguido).
	indicePortadas = map[string]map[string]string{}
)

// clavesPortadaValidas filtra y normaliza las claves que valen la pena
// indexar (se ignoran vacías, basura y las absurdamente largas).
func clavesPortadaValidas(keys []string) []string {
	vistas := map[string]bool{}
	var out []string
	for _, k := range keys {
		k = strings.TrimSpace(k)
		if len(k) < 2 || len(k) > 300 {
			continue
		}
		if !vistas[k] {
			vistas[k] = true
			out = append(out, k)
		}
		// Variante en minúsculas: el nombre de una canción puede llegar con
		// distinta capitalización desde otra fuente, y el match debe darse.
		if bajo := strings.ToLower(k); bajo != k && !vistas[bajo] {
			vistas[bajo] = true
			out = append(out, bajo)
		}
	}
	return out
}

// indiceDePortadas devuelve el índice del directorio (lo carga del disco la
// primera vez). El mapa devuelto es el vivo: mutarlo exige guardarIndice.
func indiceDePortadas(dir string) map[string]string {
	muIndicePortadas.Lock()
	defer muIndicePortadas.Unlock()
	if idx, ok := indicePortadas[dir]; ok {
		return idx
	}
	idx := map[string]string{}
	if data, err := os.ReadFile(filepath.Join(dir, archivoIndicePortadas)); err == nil {
		_ = json.Unmarshal(data, &idx)
	}
	indicePortadas[dir] = idx
	return idx
}

// guardarIndicePortadas escribe el índice a disco (best-effort: si falla, el
// índice en memoria sigue sirviendo durante esta sesión).
func guardarIndicePortadas(dir string, idx map[string]string) {
	muIndicePortadas.Lock()
	defer muIndicePortadas.Unlock()
	indicePortadas[dir] = idx
	if len(idx) == 0 {
		_ = os.Remove(filepath.Join(dir, archivoIndicePortadas))
		return
	}
	if data, err := json.Marshal(idx); err == nil {
		_ = os.WriteFile(filepath.Join(dir, archivoIndicePortadas), data, 0644)
	}
}

// registrarClavesPortada asocia cada clave a [filename] para que cualquier
// camino (like, descarga, reproducción) recupere la carátula sin red.
func registrarClavesPortada(dir string, keys []string, filename string) {
	validas := clavesPortadaValidas(keys)
	if len(validas) == 0 {
		return
	}
	idx := indiceDePortadas(dir)
	cambio := false
	for _, k := range validas {
		if idx[k] != filename {
			idx[k] = filename
			cambio = true
		}
	}
	if cambio {
		guardarIndicePortadas(dir, idx)
	}
}

// buscarClavePortada devuelve el nombre de archivo indexado para [key]
// (vacío si no está o si el archivo ya no existe).
func buscarClavePortada(dir, key string) string {
	for _, k := range clavesPortadaValidas([]string{key}) {
		nombre := indiceDePortadas(dir)[k]
		if nombre == "" {
			continue
		}
		if _, err := os.Stat(filepath.Join(dir, nombre)); err == nil {
			return nombre
		}
		// Entrada muerta (archivo borrado por fuera): se limpia al vuelo.
		olvidarArchivoPortada(dir, nombre)
	}
	return ""
}

// olvidarArchivoPortada quita del índice todas las claves de [filename]
// (se usa al borrar o evictar una carátula).
func olvidarArchivoPortada(dir, filename string) {
	idx := indiceDePortadas(dir)
	cambio := false
	for k, v := range idx {
		if v == filename {
			delete(idx, k)
			cambio = true
		}
	}
	if cambio {
		guardarIndicePortadas(dir, idx)
	}
}
