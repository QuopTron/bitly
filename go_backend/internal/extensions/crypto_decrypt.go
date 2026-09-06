package extensions

import (
	"crypto/cipher"
	"crypto/md5"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"github.com/dop251/goja"
	"golang.org/x/crypto/blowfish"
)

// registerCryptoUtils adds utils.* crypto functions to the JS sandbox.
func registerCryptoUtils(vm *goja.Runtime) {
	utilsObj := vm.NewObject()
	if existing := vm.Get("utils"); existing != nil && !goja.IsUndefined(existing) {
		if obj, ok := existing.(*goja.Object); ok {
			utilsObj = obj
		}
	}

	utilsObj.Set("md5", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		h := md5.Sum([]byte(input))
		return vm.ToValue(hex.EncodeToString(h[:]))
	})

	utilsObj.Set("sha256", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		h := sha256.Sum256([]byte(input))
		return vm.ToValue(hex.EncodeToString(h[:]))
	})

	utilsObj.Set("timestamp", func() int64 {
		return time.Now().Unix()
	})

	utilsObj.Set("timestampMs", func() int64 {
		return time.Now().UnixMilli()
	})

	utilsObj.Set("base64Encode", func(call goja.FunctionCall) goja.Value {
		data := call.Argument(0).String()
		return vm.ToValue(base64.StdEncoding.EncodeToString([]byte(data)))
	})

	utilsObj.Set("base64Decode", func(call goja.FunctionCall) goja.Value {
		data := call.Argument(0).String()
		decoded, err := base64.StdEncoding.DecodeString(data)
		if err != nil {
			return vm.ToValue("")
		}
		return vm.ToValue(string(decoded))
	})

	// utils.decryptBlockCipher(base64Data, opts) -> Blowfish CBC decrypt
	utilsObj.Set("decryptBlockCipher", func(call goja.FunctionCall) goja.Value {
		dataB64 := call.Argument(0).String()
		opts := map[string]string{}
		if o := call.Argument(1).Export(); o != nil {
			if m, ok := o.(map[string]interface{}); ok {
				for k, v := range m {
					opts[k] = fmt.Sprint(v)
				}
			}
		}

		keyHex := opts["key"]
		ivHex := opts["iv"]

		key, err := hex.DecodeString(keyHex)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("key decode: %v", err)})
		}
		iv, err := hex.DecodeString(ivHex)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("iv decode: %v", err)})
		}

		ciphertext, _ := base64.StdEncoding.DecodeString(dataB64)

		block, err := blowfish.NewCipher(key)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("blowfish: %v", err)})
		}

		if len(iv) != block.BlockSize() {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "IV size mismatch"})
		}

		mode := cipher.NewCBCDecrypter(block, iv)
		plaintext := make([]byte, len(ciphertext))
		mode.CryptBlocks(plaintext, ciphertext)

		// Strip PKCS7 padding ONLY when the caller requested it. Deezer's
		// stream encryption passes padding:"none" — every 2048-byte chunk is
		// an exact multiple of the Blowfish block size, so the plaintext is
		// the full 2048 bytes and the trailing byte is real audio data, NOT a
		// pad length. Unconditionally trimming "plaintext[last]" bytes here
		// chopped 0-255 bytes off every decrypted chunk, corrupting each chunk
		// boundary (valid header, garbage frames → "Error decoding audio").
		padding := strings.ToLower(opts["padding"])
		if padding == "" {
			padding = "pkcs7" // default to PKCS7 for API-compat callers
		}
		if padding == "pkcs7" || padding == "pkcs" {
			if len(plaintext) > 0 {
				padLen := int(plaintext[len(plaintext)-1])
				if padLen > 0 && padLen <= block.BlockSize() && padLen < len(plaintext) {
					// Validate the padding bytes before trimming (defensive: a
					// real PKCS7 pad of length n has n copies of n at the end).
					valid := true
					for i := len(plaintext) - padLen; i < len(plaintext); i++ {
						if plaintext[i] != byte(padLen) {
							valid = false
							break
						}
					}
					if valid {
						plaintext = plaintext[:len(plaintext)-padLen]
					}
				}
			}
		}

		output := base64.StdEncoding.EncodeToString(plaintext)
		return vm.ToValue(map[string]interface{}{"success": true, "data": output})
	})

	vm.Set("utils", utilsObj)
}
