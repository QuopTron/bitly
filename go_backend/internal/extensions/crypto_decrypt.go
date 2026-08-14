package extensions

import (
	"crypto/cipher"
	"crypto/md5"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
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

		// Remove PKCS7 padding
		if len(plaintext) > 0 {
			padLen := int(plaintext[len(plaintext)-1])
			if padLen < len(plaintext) {
				plaintext = plaintext[:len(plaintext)-padLen]
			}
		}

		output := base64.StdEncoding.EncodeToString(plaintext)
		return vm.ToValue(map[string]interface{}{"success": true, "data": output})
	})

	vm.Set("utils", utilsObj)
}
