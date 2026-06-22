package runtime

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/md5"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/dop251/goja"
	//lint:ignore SA1019 Blowfish is required for legacy extension crypto compatibility.
	"golang.org/x/crypto/blowfish"

	"github.com/zarz/bitly/go_backend_bitly/internal/download/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/progress"
)

func (ler *loadedExtensionRuntime) registerUtils() {
	utilsObj := ler.vm.NewObject()
	utilsObj.Set("base64Encode", ler.base64Encode)
	utilsObj.Set("base64Decode", ler.base64Decode)
	utilsObj.Set("md5", ler.md5Hash)
	utilsObj.Set("sha256", ler.sha256Hash)
	utilsObj.Set("hmacSHA256", ler.hmacSHA256)
	utilsObj.Set("hmacSHA256Base64", ler.hmacSHA256Base64)
	utilsObj.Set("hmacSHA1", ler.hmacSHA1)
	utilsObj.Set("parseJSON", ler.parseJSON)
	utilsObj.Set("stringifyJSON", ler.stringifyJSON)
	utilsObj.Set("encrypt", ler.cryptoEncrypt)
	utilsObj.Set("decrypt", ler.cryptoDecrypt)
	utilsObj.Set("encryptBlockCipher", ler.encryptBlockCipher)
	utilsObj.Set("decryptBlockCipher", ler.decryptBlockCipher)
	utilsObj.Set("generateKey", ler.cryptoGenerateKey)
	utilsObj.Set("randomUserAgent", ler.randomUserAgent)
	utilsObj.Set("sleep", ler.sleep)
	utilsObj.Set("appVersion", ler.appVersion)
	utilsObj.Set("appUserAgent", ler.appUserAgent)
	utilsObj.Set("isDownloadCancelled", ler.isDownloadCancelled)
	utilsObj.Set("isRequestCancelled", ler.isRequestCancelled)
	utilsObj.Set("setDownloadStatus", ler.setDownloadStatus)
	ler.vm.Set("utils", utilsObj)
}

func (ler *loadedExtensionRuntime) base64Encode(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue("") }
	return ler.vm.ToValue(base64.StdEncoding.EncodeToString([]byte(call.Arguments[0].String())))
}
func (ler *loadedExtensionRuntime) base64Decode(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue("") }
	d, err := base64.StdEncoding.DecodeString(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue("") }
	return ler.vm.ToValue(string(d))
}
func (ler *loadedExtensionRuntime) md5Hash(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue("") }
	h := md5.Sum([]byte(call.Arguments[0].String()))
	return ler.vm.ToValue(hex.EncodeToString(h[:]))
}
func (ler *loadedExtensionRuntime) sha256Hash(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue("") }
	h := sha256.Sum256([]byte(call.Arguments[0].String()))
	return ler.vm.ToValue(hex.EncodeToString(h[:]))
}
func (ler *loadedExtensionRuntime) hmacSHA256(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue("") }
	mac := hmac.New(sha256.New, []byte(call.Arguments[1].String()))
	mac.Write([]byte(call.Arguments[0].String()))
	return ler.vm.ToValue(hex.EncodeToString(mac.Sum(nil)))
}
func (ler *loadedExtensionRuntime) hmacSHA256Base64(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue("") }
	mac := hmac.New(sha256.New, []byte(call.Arguments[1].String()))
	mac.Write([]byte(call.Arguments[0].String()))
	return ler.vm.ToValue(base64.StdEncoding.EncodeToString(mac.Sum(nil)))
}
func (ler *loadedExtensionRuntime) hmacSHA1(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue([]byte{}) }
	mac := hmac.New(sha1.New, []byte(call.Arguments[0].String()))
	mac.Write([]byte(call.Arguments[1].String()))
	result := mac.Sum(nil)
	arr := make([]interface{}, len(result))
	for i, b := range result { arr[i] = int(b) }
	return ler.vm.ToValue(arr)
}
func (ler *loadedExtensionRuntime) parseJSON(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return goja.Undefined() }
	var result interface{}
	if err := json.Unmarshal([]byte(call.Arguments[0].String()), &result); err != nil { return goja.Undefined() }
	return ler.vm.ToValue(result)
}
func (ler *loadedExtensionRuntime) stringifyJSON(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue("") }
	data, err := json.Marshal(call.Arguments[0].Export())
	if err != nil { return ler.vm.ToValue("") }
	return ler.vm.ToValue(string(data))
}
func (ler *loadedExtensionRuntime) cryptoEncrypt(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "plaintext and key required"}) }
	key := sha256.Sum256([]byte(call.Arguments[1].String()))
	encrypted, err := encryptAESGCM([]byte(call.Arguments[0].String()), key[:])
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	return ler.vm.ToValue(map[string]interface{}{"success": true, "data": base64.StdEncoding.EncodeToString(encrypted)})
}
func (ler *loadedExtensionRuntime) cryptoDecrypt(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "ciphertext and key required"}) }
	ct, err := base64.StdEncoding.DecodeString(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "invalid base64"}) }
	key := sha256.Sum256([]byte(call.Arguments[1].String()))
	decrypted, err := decryptAESGCM(ct, key[:])
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "decryption failed"}) }
	return ler.vm.ToValue(map[string]interface{}{"success": true, "data": string(decrypted)})
}
func (ler *loadedExtensionRuntime) cryptoGenerateKey(call goja.FunctionCall) goja.Value {
	length := 32
	if len(call.Arguments) > 0 && !goja.IsUndefined(call.Arguments[0]) {
		if l, ok := call.Arguments[0].Export().(float64); ok { length = int(l) }
	}
	key := make([]byte, length)
	if _, err := rand.Read(key); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	return ler.vm.ToValue(map[string]interface{}{"success": true, "key": base64.StdEncoding.EncodeToString(key), "hex": hex.EncodeToString(key)})
}

// randomUserAgent returns a random Chrome user-agent string.
func (ler *loadedExtensionRuntime) randomUserAgent(call goja.FunctionCall) goja.Value {
	n, _ := rand.Int(rand.Reader, big.NewInt(26))
	chromeVersion := int(n.Int64()) + 120
	n, _ = rand.Int(rand.Reader, big.NewInt(1500))
	chromeBuild := int(n.Int64()) + 6000
	n, _ = rand.Int(rand.Reader, big.NewInt(200))
	chromePatch := int(n.Int64()) + 100
	ua := fmt.Sprintf(
		"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/%d.0.%d.%d Safari/537.36",
		chromeVersion, chromeBuild, chromePatch,
	)
	return ler.vm.ToValue(ua)
}

func (ler *loadedExtensionRuntime) appVersion(call goja.FunctionCall) goja.Value {
	return ler.vm.ToValue("1.0.0")
}

func (ler *loadedExtensionRuntime) appUserAgent(call goja.FunctionCall) goja.Value {
	return ler.vm.ToValue("Bitly-Extension/1.0")
}

// sleep pauses execution for the given milliseconds, checking for download cancellation.
func (ler *loadedExtensionRuntime) sleep(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(true) }
	sleepMs := int(call.Arguments[0].ToInteger())
	if sleepMs <= 0 { return ler.vm.ToValue(true) }
	if sleepMs > 5*60*1000 { sleepMs = 5 * 60 * 1000 }

	itemID := ler.getActiveDownloadItemID()
	deadline := time.Now().Add(time.Duration(sleepMs) * time.Millisecond)
	for {
		if itemID != "" && core.IsDownloadCancelled(itemID) {
			return ler.vm.ToValue(false)
		}
		remaining := time.Until(deadline)
		if remaining <= 0 {
			return ler.vm.ToValue(true)
		}
		step := 100 * time.Millisecond
		if remaining < step {
			step = remaining
		}
		time.Sleep(step)
	}
}

func (ler *loadedExtensionRuntime) isDownloadCancelled(call goja.FunctionCall) goja.Value {
	itemID := ler.getActiveDownloadItemID()
	if itemID == "" { return ler.vm.ToValue(false) }
	return ler.vm.ToValue(core.IsDownloadCancelled(itemID))
}

func (ler *loadedExtensionRuntime) isRequestCancelled(call goja.FunctionCall) goja.Value {
	requestID := ler.getActiveRequestID()
	if requestID == "" { return ler.vm.ToValue(false) }
	return ler.vm.ToValue(core.IsExtensionRequestCancelled(requestID))
}

func (ler *loadedExtensionRuntime) setDownloadStatus(call goja.FunctionCall) goja.Value {
	itemID := ler.getActiveDownloadItemID()
	if itemID == "" || len(call.Arguments) < 1 { return goja.Undefined() }
	status := strings.ToLower(strings.TrimSpace(call.Arguments[0].String()))
	switch status {
	case "preparing":
		progress.SetItemPreparing(itemID)
	case "downloading":
		progress.SetItemDownloading(itemID)
	case "finalizing":
		progress.SetItemFinalizing(itemID)
	}
	return goja.Undefined()
}

// --- Block cipher (AES/Blowfish CBC) ---

type runtimeBlockCipherOptions struct {
	Algorithm      string
	Mode           string
	Key            []byte
	IV             []byte
	InputEncoding  string
	OutputEncoding string
	Padding        string
}

func parseRuntimeOptionsArgument(call goja.FunctionCall, index int) map[string]interface{} {
	if len(call.Arguments) <= index { return nil }
	value := call.Arguments[index]
	if goja.IsUndefined(value) || goja.IsNull(value) { return nil }
	exported := value.Export()
	if options, ok := exported.(map[string]interface{}); ok { return options }
	return nil
}

func runtimeOptionString(options map[string]interface{}, key, defaultValue string) string {
	if options == nil { return defaultValue }
	raw, ok := options[key]
	if !ok || raw == nil { return defaultValue }
	switch value := raw.(type) {
	case string:
		if trimmed := strings.TrimSpace(value); trimmed != "" { return trimmed }
	case []byte:
		if len(value) > 0 { return string(value) }
	}
	return defaultValue
}

func runtimeOptionBool(options map[string]interface{}, key string, defaultValue bool) bool {
	if options == nil { return defaultValue }
	raw, ok := options[key]
	if !ok || raw == nil { return defaultValue }
	switch value := raw.(type) {
	case bool: return value
	case int: return value != 0
	case int64: return value != 0
	case float64: return value != 0
	case string:
		switch strings.ToLower(strings.TrimSpace(value)) {
		case "1", "true", "yes", "on": return true
		case "0", "false", "no", "off": return false
		}
	}
	return defaultValue
}

func runtimeOptionInt64(options map[string]interface{}, key string, defaultValue int64) int64 {
	if options == nil { return defaultValue }
	raw, ok := options[key]
	if !ok || raw == nil { return defaultValue }
	switch value := raw.(type) {
	case int: return int64(value)
	case int32: return int64(value)
	case int64: return value
	case float32: return int64(value)
	case float64: return int64(value)
	case string:
		value = strings.TrimSpace(value)
		if value == "" { return defaultValue }
		var parsed int64
		if _, err := fmt.Sscanf(value, "%d", &parsed); err == nil { return parsed }
	}
	return defaultValue
}

func runtimeOptionHasKey(options map[string]interface{}, key string) bool {
	if options == nil { return false }
	_, exists := options[key]
	return exists
}

func decodeRuntimeBytesString(input, encoding string) ([]byte, error) {
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

func decodeRuntimeBytesValue(raw interface{}, encoding string) ([]byte, error) {
	switch value := raw.(type) {
	case string:
		return decodeRuntimeBytesString(value, encoding)
	case []byte:
		cloned := make([]byte, len(value))
		copy(cloned, value)
		return cloned, nil
	case []interface{}:
		decoded := make([]byte, len(value))
		for i, item := range value {
			switch num := item.(type) {
			case int: decoded[i] = byte(num)
			case int64: decoded[i] = byte(num)
			case float64: decoded[i] = byte(int(num))
			default:
				return nil, fmt.Errorf("unsupported byte array item at index %d", i)
			}
		}
		return decoded, nil
	default:
		return nil, fmt.Errorf("unsupported byte payload type")
	}
}

func encodeRuntimeBytes(data []byte, encoding string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(encoding)) {
	case "", "base64":
		return base64.StdEncoding.EncodeToString(data), nil
	case "hex":
		return hex.EncodeToString(data), nil
	case "utf8", "utf-8", "text":
		return string(data), nil
	default:
		return "", fmt.Errorf("unsupported byte encoding: %s", encoding)
	}
}

func parseRuntimeBlockCipherOptions(options map[string]interface{}) (*runtimeBlockCipherOptions, error) {
	parsed := &runtimeBlockCipherOptions{
		Algorithm:      strings.ToLower(runtimeOptionString(options, "algorithm", "")),
		Mode:           strings.ToLower(runtimeOptionString(options, "mode", "cbc")),
		InputEncoding:  strings.ToLower(runtimeOptionString(options, "inputEncoding", "base64")),
		OutputEncoding: strings.ToLower(runtimeOptionString(options, "outputEncoding", "base64")),
		Padding:        strings.ToLower(runtimeOptionString(options, "padding", "none")),
	}
	if parsed.Algorithm == "" { return nil, fmt.Errorf("algorithm is required") }
	key, err := decodeRuntimeBytesString(
		runtimeOptionString(options, "key", ""),
		runtimeOptionString(options, "keyEncoding", "utf8"),
	)
	if err != nil { return nil, fmt.Errorf("invalid key: %w", err) }
	if len(key) == 0 { return nil, fmt.Errorf("key is required") }
	parsed.Key = key
	iv, err := decodeRuntimeBytesString(
		runtimeOptionString(options, "iv", ""),
		runtimeOptionString(options, "ivEncoding", "utf8"),
	)
	if err != nil { return nil, fmt.Errorf("invalid iv: %w", err) }
	parsed.IV = iv
	return parsed, nil
}

func newRuntimeBlockCipher(options *runtimeBlockCipherOptions) (cipher.Block, error) {
	switch options.Algorithm {
	case "blowfish":
		return blowfish.NewCipher(options.Key)
	case "aes":
		return aes.NewCipher(options.Key)
	default:
		return nil, fmt.Errorf("unsupported block cipher algorithm: %s", options.Algorithm)
	}
}

func applyPKCS7Padding(data []byte, blockSize int) []byte {
	padding := blockSize - (len(data) % blockSize)
	if padding == 0 { padding = blockSize }
	out := make([]byte, len(data)+padding)
	copy(out, data)
	for i := len(data); i < len(out); i++ {
		out[i] = byte(padding)
	}
	return out
}

func removePKCS7Padding(data []byte, blockSize int) ([]byte, error) {
	if len(data) == 0 || len(data)%blockSize != 0 {
		return nil, fmt.Errorf("invalid padded payload length")
	}
	padding := int(data[len(data)-1])
	if padding <= 0 || padding > blockSize || padding > len(data) {
		return nil, fmt.Errorf("invalid PKCS7 padding")
	}
	for i := len(data) - padding; i < len(data); i++ {
		if int(data[i]) != padding {
			return nil, fmt.Errorf("invalid PKCS7 padding")
		}
	}
	return data[:len(data)-padding], nil
}

func (ler *loadedExtensionRuntime) transformBlockCipher(call goja.FunctionCall, decrypt bool) goja.Value {
	if len(call.Arguments) < 2 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "data and options required"})
	}
	options := parseRuntimeOptionsArgument(call, 1)
	parsedOptions, err := parseRuntimeBlockCipherOptions(options)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	if parsedOptions.Mode != "cbc" {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("unsupported block cipher mode: %s", parsedOptions.Mode)})
	}
	inputData, err := decodeRuntimeBytesValue(call.Arguments[0].Export(), parsedOptions.InputEncoding)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	block, err := newRuntimeBlockCipher(parsedOptions)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	if len(parsedOptions.IV) != block.BlockSize() {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("iv must be %d bytes for %s", block.BlockSize(), parsedOptions.Algorithm)})
	}
	data := inputData
	if !decrypt && parsedOptions.Padding == "pkcs7" {
		data = applyPKCS7Padding(data, block.BlockSize())
	}
	if len(data)%block.BlockSize() != 0 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("input length must be a multiple of %d bytes", block.BlockSize())})
	}
	output := make([]byte, len(data))
	if decrypt {
		cipher.NewCBCDecrypter(block, parsedOptions.IV).CryptBlocks(output, data)
		if parsedOptions.Padding == "pkcs7" {
			output, err = removePKCS7Padding(output, block.BlockSize())
			if err != nil {
				return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
			}
		}
	} else {
		cipher.NewCBCEncrypter(block, parsedOptions.IV).CryptBlocks(output, data)
	}
	encoded, err := encodeRuntimeBytes(output, parsedOptions.OutputEncoding)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	return ler.vm.ToValue(map[string]interface{}{"success": true, "data": encoded, "block_size": block.BlockSize()})
}

func (ler *loadedExtensionRuntime) encryptBlockCipher(call goja.FunctionCall) goja.Value {
	return ler.transformBlockCipher(call, false)
}

func (ler *loadedExtensionRuntime) decryptBlockCipher(call goja.FunctionCall) goja.Value {
	return ler.transformBlockCipher(call, true)
}
