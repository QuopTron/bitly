package extensions

import (
	"crypto/hmac"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/base64"
	"encoding/hex"
	"fmt"

	"github.com/dop251/goja"
)

// registerCrypto adds crypto functions to the JS sandbox.
func registerCrypto(s *Sandbox) {
	vm := s.VM
	cryptoObj := vm.NewObject()

	cryptoObj.Set("md5", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		h := md5.Sum([]byte(input))
		return vm.ToValue(hex.EncodeToString(h[:]))
	})

	cryptoObj.Set("sha1", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		h := sha1.Sum([]byte(input))
		return vm.ToValue(hex.EncodeToString(h[:]))
	})

	cryptoObj.Set("sha256", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		h := sha256.Sum256([]byte(input))
		return vm.ToValue(hex.EncodeToString(h[:]))
	})

	cryptoObj.Set("sha512", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		h := sha512.Sum512([]byte(input))
		return vm.ToValue(hex.EncodeToString(h[:]))
	})

	cryptoObj.Set("hmac", func(call goja.FunctionCall) goja.Value {
		key := call.Argument(0).String()
		data := call.Argument(1).String()
		algo := call.Argument(2).String()
		switch algo {
		case "sha256":
			mac := hmac.New(sha256.New, []byte(key))
			mac.Write([]byte(data))
			return vm.ToValue(hex.EncodeToString(mac.Sum(nil)))
		case "sha1":
			mac := hmac.New(sha1.New, []byte(key))
			mac.Write([]byte(data))
			return vm.ToValue(hex.EncodeToString(mac.Sum(nil)))
		default:
			panic(vm.NewTypeError(fmt.Sprintf("unsupported HMAC algo: %s", algo)))
		}
	})

	cryptoObj.Set("base64encode", func(call goja.FunctionCall) goja.Value {
		data := call.Argument(0).String()
		return vm.ToValue(base64.StdEncoding.EncodeToString([]byte(data)))
	})

	cryptoObj.Set("base64decode", func(call goja.FunctionCall) goja.Value {
		data := call.Argument(0).String()
		decoded, err := base64.StdEncoding.DecodeString(data)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		return vm.ToValue(string(decoded))
	})

	cryptoObj.Set("hexEncode", func(call goja.FunctionCall) goja.Value {
		data := call.Argument(0).String()
		return vm.ToValue(hex.EncodeToString([]byte(data)))
	})

	cryptoObj.Set("hexDecode", func(call goja.FunctionCall) goja.Value {
		data := call.Argument(0).String()
		decoded, err := hex.DecodeString(data)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		return vm.ToValue(string(decoded))
	})

	vm.Set("crypto", cryptoObj)
	registerCryptoUtils(vm)
}
