package extensions

import (
	"crypto/cipher"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/dop251/goja"
	//lint:ignore SA1019 Deezer Blowfish DRM: el algoritmo lo exige el cifrado de Deezer (no reemplazable por AES).
	"golang.org/x/crypto/blowfish"
)

// registerFileTransformOps expone file.transformPatternedBlocks, el transform
// por bloques que Deezer necesita.
//
// El stream de Deezer llega con un patrón fijo: cada TERCER bloque de 2048
// bytes (índices 0, 3, 6, ...) viene cifrado con Blowfish-CBC y el resto ya en
// claro. Descifrar exactamente esos bloques —y ninguno más— reproduce el audio
// original; tocar cualquier otro lo corrompe.
//
// Se hace en Go (no desde JS) porque la versión anterior leía y reescribía cada
// bloque de 2 KB a través del sandbox: para un FLAC de ~50 MB eran ~25.000
// round-trips JS→Go con base64 de por medio. Acá se procesa por streaming.
//
// Se conecta con: la extensión deezer (bundled_extensions/deezer/index.js,
// función decryptDownloadedFile) y con internal/download/decrypt_keys.go.
// Parte del flujo: descarga de Deezer (descifrado posterior a la descarga).
func registerFileTransformOps(s *Sandbox, fileObj *goja.Object) {
	vm := s.VM

	fileObj.Set("transformPatternedBlocks", func(call goja.FunctionCall) goja.Value {
		inputPath := call.Argument(0).String()
		outputPath := call.Argument(1).String()

		opts := map[string]interface{}{}
		if o := call.Argument(2).Export(); o != nil {
			if m, ok := o.(map[string]interface{}); ok {
				opts = m
			}
		}

		inFull, err := resolverRuta(s, inputPath)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
		}
		outFull, err := resolverRuta(s, outputPath)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
		}

		operation := strings.ToLower(runtimeOptString(opts, "operation", "decrypt"))
		if operation != "decrypt" && operation != "encrypt" {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("unsupported operation: %s", operation)})
		}
		algorithm := strings.ToLower(runtimeOptString(opts, "algorithm", "blowfish"))
		if algorithm != "blowfish" {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("unsupported algorithm: %s", algorithm)})
		}
		if mode := strings.ToLower(runtimeOptString(opts, "mode", "cbc")); mode != "cbc" {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("unsupported mode: %s", mode)})
		}
		if enc := strings.ToLower(runtimeOptString(opts, "keyEncoding", "hex")); enc != "hex" {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "only hex key encoding is supported"})
		}
		if enc := strings.ToLower(runtimeOptString(opts, "ivEncoding", "hex")); enc != "hex" {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "only hex iv encoding is supported"})
		}

		key, err := hex.DecodeString(strings.TrimSpace(runtimeOptString(opts, "key", "")))
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("key decode: %v", err)})
		}
		iv, err := hex.DecodeString(strings.TrimSpace(runtimeOptString(opts, "iv", "")))
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("iv decode: %v", err)})
		}

		block, err := blowfish.NewCipher(key)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("blowfish: %v", err)})
		}
		if len(iv) != block.BlockSize() {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "IV size mismatch"})
		}

		segmentSize := int(runtimeOptInt64(opts, "segmentSize", 2048))
		if segmentSize <= 0 {
			segmentSize = 2048
		}
		transformEvery := int(runtimeOptInt64(opts, "transformEvery", 3))
		if transformEvery <= 0 {
			transformEvery = 1
		}
		transformOffset := int(runtimeOptInt64(opts, "transformOffset", 0))
		transformPartial := runtimeOptBool(opts, "transformPartial", false)
		padding := strings.ToLower(runtimeOptString(opts, "padding", "none"))

		// El callback de progreso se invoca SIEMPRE desde esta goroutine (la que
		// tiene el lock del VM), nunca desde un worker.
		progress := newJSCallback(vm, call.Argument(3), 100)

		in, err := os.Open(inFull)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("open: %v", err)})
		}
		defer in.Close()

		info, err := in.Stat()
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("stat: %v", err)})
		}
		total := info.Size()

		out, err := os.Create(outFull)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("create: %v", err)})
		}

		segment := make([]byte, segmentSize)
		processed := int64(0)
		index := 0

		for {
			n, readErr := io.ReadFull(in, segment)
			if n > 0 {
				chunk := segment[:n]
				// Solo se transforma un bloque COMPLETO (salvo que el llamador
				// pida explícitamente parciales) y solo si cae en el patrón.
				// Un bloque incompleto nunca es múltiplo del tamaño de bloque de
				// Blowfish, así que transformarlo corrompería el final del archivo.
				full := n == segmentSize
				matchesPattern := index%transformEvery == transformOffset%transformEvery
				if (full || transformPartial) && matchesPattern && n%block.BlockSize() == 0 {
					var mode cipher.BlockMode
					if operation == "encrypt" {
						mode = cipher.NewCBCEncrypter(block, iv)
					} else {
						mode = cipher.NewCBCDecrypter(block, iv)
					}
					transformed := make([]byte, n)
					mode.CryptBlocks(transformed, chunk)
					// Deezer usa padding:"none": el bloque descifrado son los
					// 2048 bytes reales de audio, NO un padding PKCS7. Recortar
					// aquí quitaría 0-255 bytes en cada frontera y corrompería
					// los frames (header válido + audio basura).
					if operation == "decrypt" && (padding == "pkcs7" || padding == "pkcs") {
						transformed = stripPaddingPKCS7(transformed, block.BlockSize())
					}
					chunk = transformed
				}
				if _, err := out.Write(chunk); err != nil {
					out.Close()
					return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("write: %v", err)})
				}
				processed += int64(n)
				index++
				progress.call(processed, total)
			}
			if readErr == io.EOF || readErr == io.ErrUnexpectedEOF {
				break
			}
			if readErr != nil {
				out.Close()
				return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("read: %v", readErr)})
			}
		}

		if err := out.Close(); err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("close: %v", err)})
		}
		progress.callFinal(processed, total)
		return vm.ToValue(map[string]interface{}{"success": true, "path": outFull, "size": processed})
	})
}

// stripPaddingPKCS7 recorta un padding PKCS7 válido. Solo se usa cuando el
// llamador pide padding:"pkcs7"; valida los bytes de relleno antes de recortar
// para no comerse audio real si el último byte casualmente parece un padding.
func stripPaddingPKCS7(data []byte, blockSize int) []byte {
	if len(data) == 0 {
		return data
	}
	padLen := int(data[len(data)-1])
	if padLen <= 0 || padLen > blockSize || padLen >= len(data) {
		return data
	}
	for i := len(data) - padLen; i < len(data); i++ {
		if data[i] != byte(padLen) {
			return data
		}
	}
	return data[:len(data)-padLen]
}
