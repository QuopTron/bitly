package gobackend

// Descarga y validación de tipografías, separadas de fuentes.go para poder
// probarlas solas (sin red y sin tocar el disco de la app).
//
// Por qué se valida la FIRMA y no sólo el status HTTP: un espejo caído, un
// proxy con portal cautivo o una URL mal escrita contestan 200 con una página
// HTML de error. Sin este chequeo ese HTML se guardaría como .ttf, Flutter
// fallaría al registrarlo y la tipografía quedaría "elegida" pero invisible —
// peor que un error, porque no se puede distinguir de que funcionó.

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

// errFuenteNoEsFuente marca respuestas 200 que no son una tipografía real.
var errFuenteNoEsFuente = errors.New("la respuesta no es una tipografía")

// idFuenteValido acepta sólo ids que sean un nombre de archivo seguro.
var idFuenteValidoRe = regexp.MustCompile(`^[a-z0-9_]{1,32}$`)

// Tope de tamaño de una tipografía. Una familia completa ronda los 1-4 MB; 16
// MB deja aire para una variable font sin que una respuesta inesperada llene
// el almacenamiento del usuario.
const maxBytesFuente = 16 * 1024 * 1024

// idFuenteValido dice si el id puede usarse como nombre de archivo.
func idFuenteValido(id string) bool { return idFuenteValidoRe.MatchString(id) }

// firmaFuente reconoce el encabezado de un archivo sfnt (TTF/OTF/colección).
//
// El primer campo de un sfnt es su "versión": 0x00010000 para TrueType, o la
// etiqueta ASCII de la variante. Un HTML empieza con "<!DO" o "<htm", así que
// no pasa.
func firmaFuente(data []byte) bool {
	if len(data) < 12 {
		return false
	}
	switch string(data[:4]) {
	case "true", "OTTO", "ttcf", "typ1":
		return true
	}
	return data[0] == 0x00 && data[1] == 0x01 && data[2] == 0x00 && data[3] == 0x00
}

// coincideSHA256 compara la huella del archivo con la esperada. Con esperado
// vacío no se verifica (el catálogo todavía no pinnea huellas) y devuelve true:
// la firma sfnt ya descartó lo grosero.
func coincideSHA256(data []byte, esperado string) bool {
	if esperado == "" {
		return true
	}
	sum := sha256.Sum256(data)
	return strings.EqualFold(hex.EncodeToString(sum[:]), esperado)
}

// archivoFuenteSano dice si lo que ya está en disco sirve: tiene firma de
// tipografía y, si el catálogo la declara, la huella esperada.
func archivoFuenteSano(path, sha256Esperado string) bool {
	data, err := os.ReadFile(path)
	if err != nil || !firmaFuente(data) {
		return false
	}
	return coincideSHA256(data, sha256Esperado)
}

// descargarFuenteBytes baja la tipografía de [url] y devuelve sus bytes.
func descargarFuenteBytes(url string) ([]byte, error) {
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		return nil, fmt.Errorf("url inválida: %q", url)
	}
	// Timeout más generoso que el de las carátulas: una familia entera pesa
	// varios MB y en una conexión lenta 15s no alcanzan.
	client := &http.Client{Timeout: 60 * time.Second}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	// Varios espejos (GitHub releases incluido) contestan 403 sin User-Agent.
	req.Header.Set("User-Agent", userAgentPortadas)
	req.Header.Set("Accept", "font/ttf,font/otf,application/octet-stream,*/*;q=0.8")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxBytesFuente))
	if err != nil {
		return nil, err
	}
	if !firmaFuente(data) {
		return nil, errFuenteNoEsFuente
	}
	return data, nil
}

// escribirAtomico escribe primero en un temporal y después renombra.
//
// Sin esto, una descarga cortada a la mitad dejaba un .ttf truncado que el
// chequeo de firma del próximo arranque descarta... pero que mientras tanto la
// app pudo haber intentado registrar, y el rename es lo que hace que en disco
// sólo exista el archivo COMPLETO.
func escribirAtomico(path string, data []byte) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0644); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return nil
}
