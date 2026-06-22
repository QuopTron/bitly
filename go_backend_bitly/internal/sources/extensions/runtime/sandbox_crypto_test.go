package runtime

import (
	"testing"
)

func cryptoTestVM(t *testing.T, jsCode string) {
	t.Helper()
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { test: function() {`+jsCode+`} };`)
	if err := r.LoadExtensionWithDirs("crypto", jsPath, t.TempDir(), t.TempDir(), nil); err != nil {
		t.Fatal(err)
	}
	if _, err := r.CallMethod("crypto", "test"); err != nil {
		t.Fatal(err)
	}
}

func TestCrypto_Base64Encode(t *testing.T) {
	cryptoTestVM(t, `
		var s = utils.base64Encode("hello");
		if (typeof s !== "string" || s.length === 0) throw new Error("base64Encode failed: " + s);
	`)
}

func TestCrypto_Base64Decode(t *testing.T) {
	cryptoTestVM(t, `
		var encoded = utils.base64Encode("hello world");
		var decoded = utils.base64Decode(encoded);
		if (decoded !== "hello world") throw new Error("base64Decode: " + decoded);
	`)
}

func TestCrypto_MD5(t *testing.T) {
	cryptoTestVM(t, `
		var hash = utils.md5("hello");
		if (typeof hash !== "string" || hash.length !== 32) throw new Error("md5 bad: " + hash);
	`)
}

func TestCrypto_SHA256(t *testing.T) {
	cryptoTestVM(t, `
		var hash = utils.sha256("hello");
		if (typeof hash !== "string" || hash.length !== 64) throw new Error("sha256 bad: " + hash);
	`)
}

func TestCrypto_HMACSHA256(t *testing.T) {
	cryptoTestVM(t, `
		var hmac = utils.hmacSHA256("key", "data");
		if (typeof hmac !== "string" || hmac.length === 0) throw new Error("hmacSHA256 failed");
	`)
}

func TestCrypto_HMACSHA256_Deterministic(t *testing.T) {
	cryptoTestVM(t, `
		var h1 = utils.hmacSHA256("message", "secret");
		var h2 = utils.hmacSHA256("message", "secret");
		if (h1 !== h2) throw new Error("hmac should be deterministic");
	`)
}

func TestCrypto_HMACSHA1(t *testing.T) {
	cryptoTestVM(t, `
		var hmac = utils.hmacSHA1("key", "data");
		if (!Array.isArray(hmac) || hmac.length === 0) throw new Error("hmacSHA1 should return array");
	`)
}

func TestCrypto_ParseJSON(t *testing.T) {
	cryptoTestVM(t, `
		var obj = utils.parseJSON('{"a":1,"b":"two"}');
		if (obj.a !== 1 || obj.b !== "two") throw new Error("parseJSON failed");
	`)
}

func TestCrypto_StringifyJSON(t *testing.T) {
	cryptoTestVM(t, `
		var str = utils.stringifyJSON({x: 10, y: "z"});
		var obj = JSON.parse(str);
		if (obj.x !== 10 || obj.y !== "z") throw new Error("stringifyJSON: " + str);
	`)
}

func TestCrypto_Sleep(t *testing.T) {
	cryptoTestVM(t, `
		var start = Date.now();
		utils.sleep(50);
		var elapsed = Date.now() - start;
		if (elapsed < 30) throw new Error("sleep too short: " + elapsed);
	`)
}

func TestCrypto_RandomUserAgent(t *testing.T) {
	cryptoTestVM(t, `
		var ua = utils.randomUserAgent();
		if (typeof ua !== "string" || ua.length < 10) throw new Error("bad UA: " + ua);
	`)
}

func TestCrypto_AppVersion(t *testing.T) {
	cryptoTestVM(t, `
		var v = utils.appVersion();
		if (typeof v !== "string") throw new Error("appVersion failed");
	`)
}

func TestCrypto_EncryptDecrypt(t *testing.T) {
	cryptoTestVM(t, `
		var key = utils.generateKey();
		if (!key.success) throw new Error("generateKey failed: " + JSON.stringify(key));
		var plaintext = "secret message 123";
		var encrypted = utils.encrypt(plaintext, key.key);
		if (!encrypted.success) throw new Error("encrypt failed: " + JSON.stringify(encrypted));
		var decrypted = utils.decrypt(encrypted.data, key.key);
		if (!decrypted.success) throw new Error("decrypt failed: " + JSON.stringify(decrypted));
		if (decrypted.data !== plaintext) throw new Error("decrypt mismatch: " + decrypted.data);
	`)
}

func TestCrypto_EncryptDecrypt_Unicode(t *testing.T) {
	cryptoTestVM(t, `
		var key = utils.generateKey();
		if (!key.success) throw new Error("generateKey failed");
		var plaintext = "héllo ✓ 中文";
		var encrypted = utils.encrypt(plaintext, key.key);
		if (!encrypted.success) throw new Error("encrypt failed");
		var decrypted = utils.decrypt(encrypted.data, key.key);
		if (!decrypted.success || decrypted.data !== plaintext) throw new Error("unicode decrypt mismatch: " + JSON.stringify(decrypted));
	`)
}

func TestCrypto_Encrypt_WrongKey(t *testing.T) {
	cryptoTestVM(t, `
		var key1 = utils.generateKey();
		var key2 = utils.generateKey();
		var encrypted = utils.encrypt("test", key1.key);
		var decrypted = utils.decrypt(encrypted.data, key2.key);
		if (decrypted.success === true) throw new Error("should fail for wrong key");
	`)
}

func TestCrypto_DownloadCancelled(t *testing.T) {
	cryptoTestVM(t, `
		var v = utils.isDownloadCancelled();
		if (typeof v !== "boolean") throw new Error("isDownloadCancelled should be boolean");
	`)
}

func TestCrypto_RequestCancelled(t *testing.T) {
	cryptoTestVM(t, `
		var v = utils.isRequestCancelled();
		if (typeof v !== "boolean") throw new Error("isRequestCancelled should be boolean");
	`)
}

func TestCrypto_Base64Roundtrip(t *testing.T) {
	cryptoTestVM(t, `
		var inputs = ["", "a", "ab", "abc", "hello world"];
		for (var i = 0; i < inputs.length; i++) {
			var enc = utils.base64Encode(inputs[i]);
			var dec = utils.base64Decode(enc);
			if (dec !== inputs[i]) throw new Error("mismatch at " + i + ": " + dec);
		}
	`)
}

func TestCrypto_GenerateKey(t *testing.T) {
	cryptoTestVM(t, `
		var k1 = utils.generateKey();
		var k2 = utils.generateKey();
		if (!k1.success || typeof k1.key !== "string" || k1.key.length < 10) throw new Error("bad key1");
		if (k1.key === k2.key) throw new Error("keys should be unique");
	`)
}

func TestCrypto_GenerateKey_CustomLength(t *testing.T) {
	cryptoTestVM(t, `
		var k = utils.generateKey(16);
		if (!k.success) throw new Error("generateKey failed");
	`)
}
