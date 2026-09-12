// Puente de la BIBLIOTECA LOCAL hacia Flutter.
//
// Qué hace: expone a la app el escaneo de una carpeta de música propia y el
// dedupe por ISRC. ImportarBibliotecaLocal es la puerta de entrada de la
// importación (compras de Amazon, archivos de iTunes Match, FLAC propios);
// FaltantesLocales es lo que consulta la descarga para no volver a bajar lo
// que el usuario ya tiene en disco.
//
// Se conecta con: library.Scan (rastreo de archivos), library.IndiceLocal
// (mapa ISRC → ruta) y el puente RPC (bridge_rpc.go) que lo llama desde Dart.
package gobackend

import (
	"encoding/json"
)

// =========================================================================
// BIBLIOTECA LOCAL
// =========================================================================

// ScanLibrary escanea una carpeta y devuelve sus archivos de audio con
// metadata. Además los deja indexados por ISRC para el dedupe de descargas.
func ScanLibrary(directory string) string {
	if lib == nil {
		return `{"error":"no inicializado"}`
	}
	entries, err := lib.Scan(directory)
	if err != nil {
		return jsonError(err)
	}
	if indiceLocal != nil {
		indiceLocal.IndexarEntradas(entries)
	}
	data, _ := json.Marshal(entries)
	return string(data)
}

// ImportarBibliotecaLocal escanea la carpeta elegida por el usuario, la indexa
// por ISRC y devuelve un resumen con cuántos archivos vio, cuántos traían ISRC
// y cuántos quedaron indexados en total.
func ImportarBibliotecaLocal(directory string) string {
	if lib == nil || indiceLocal == nil {
		return `{"error":"no inicializado"}`
	}
	entries, err := lib.Scan(directory)
	if err != nil {
		return jsonError(err)
	}
	resumen := map[string]interface{}{
		"archivos":  len(entries),
		"conIsrc":   indiceLocal.IndexarEntradas(entries),
		"indexados": indiceLocal.Cantidad(),
		// Las entradas van al cliente para que las guarde en la biblioteca que
		// muestra Mi Espacio (historial de descargas) con su ruta local.
		"entradas": entries,
	}
	data, _ := json.Marshal(resumen)
	return string(data)
}

// FaltantesLocales recibe un JSON con una lista de ISRCs y devuelve solo los
// que NO están en la biblioteca local. La descarga lo usa para saltarse lo que
// el usuario ya posee.
func FaltantesLocales(isrcsJSON string) string {
	if indiceLocal == nil {
		return `[]`
	}
	var isrcs []string
	if err := json.Unmarshal([]byte(isrcsJSON), &isrcs); err != nil {
		return jsonError(err)
	}
	faltan := indiceLocal.Faltantes(isrcs)
	if faltan == nil {
		faltan = []string{}
	}
	data, _ := json.Marshal(faltan)
	return string(data)
}

// RutaLocalISRC devuelve la ruta del archivo local para un ISRC ("" si no está).
func RutaLocalISRC(isrc string) string {
	ruta := ""
	if indiceLocal != nil {
		ruta = indiceLocal.RutaLocal(isrc)
	}
	data, _ := json.Marshal(map[string]string{"filePath": ruta})
	return string(data)
}

func GetLibraryStats() string {
	if lib == nil {
		return `{}`
	}
	data, _ := json.Marshal(lib.GetStats())
	return string(data)
}
