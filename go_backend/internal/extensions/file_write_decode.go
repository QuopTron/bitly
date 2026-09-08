package extensions

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"

	"github.com/dop251/goja"
)

// decodificarBytesValor convierte un payload goja (string / []byte / ArrayBuffer /
// []int) a bytes usando la codificación pedida (base64 por defecto, hex o utf8).
func decodificarBytesValor(raw interface{}, encoding string) ([]byte, error) {
	switch v := raw.(type) {
	case string:
		return decodificarBytesString(v, encoding)
	case []byte:
		out := make([]byte, len(v))
		copy(out, v)
		return out, nil
	case goja.ArrayBuffer:
		src := v.Bytes()
		out := make([]byte, len(src))
		copy(out, src)
		return out, nil
	case []interface{}:
		out := make([]byte, len(v))
		for i, item := range v {
			switch n := item.(type) {
			case int:
				out[i] = byte(n)
			case int64:
				out[i] = byte(n)
			case float64:
				out[i] = byte(int(n))
			default:
				return nil, fmt.Errorf("unsupported byte array item at index %d", i)
			}
		}
		return out, nil
	default:
		return nil, fmt.Errorf("unsupported byte payload type")
	}
}

// decodificarBytesString decodifica un string según la codificación indicada.
func decodificarBytesString(input, encoding string) ([]byte, error) {
	switch strings.ToLower(strings.TrimSpace(encoding)) {
	case "", "utf8", "utf-8", "text":
		return []byte(input), nil
	case "base64":
		decoded, err := base64.StdEncoding.DecodeString(strings.TrimSpace(input))
		if err != nil {
			return nil, fmt.Errorf("invalid base64 data: %w", err)
		}
		return decoded, nil
	case "hex":
		decoded, err := hex.DecodeString(strings.TrimSpace(input))
		if err != nil {
			return nil, fmt.Errorf("invalid hex data: %w", err)
		}
		return decoded, nil
	default:
		return nil, fmt.Errorf("unsupported byte encoding: %s", encoding)
	}
}
