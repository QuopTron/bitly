package runtime

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/dop251/goja"
)

const storageFlushRetryDelay = 2 * time.Second

func (ler *loadedExtensionRuntime) registerStorage() {
	storageObj := ler.vm.NewObject()
	storageObj.Set("get", ler.storageGet)
	storageObj.Set("set", ler.storageSet)
	storageObj.Set("remove", ler.storageRemove)
	ler.vm.Set("storage", storageObj)
}

func (ler *loadedExtensionRuntime) getStoragePath() string {
	return filepath.Join(ler.dataDir, "storage.json")
}

func (ler *loadedExtensionRuntime) ensureStorageLoaded() error {
	ler.storageMu.RLock()
	if ler.storageLoaded { ler.storageMu.RUnlock(); return nil }
	ler.storageMu.RUnlock()
	ler.storageMu.Lock()
	defer ler.storageMu.Unlock()
	if ler.storageLoaded { return nil }
	data, err := os.ReadFile(ler.getStoragePath())
	if err != nil {
		if os.IsNotExist(err) { ler.storageCache = make(map[string]interface{}); ler.storageLoaded = true; return nil }
		return err
	}
	var storage map[string]interface{}
	if err := json.Unmarshal(data, &storage); err != nil { return err }
	if storage == nil { storage = make(map[string]interface{}) }
	ler.storageCache = storage
	ler.storageLoaded = true
	return nil
}

func (ler *loadedExtensionRuntime) queueStorageFlushLocked(delay time.Duration) {
	if ler.storageClosed || ler.storageTimer != nil { return }
	ler.storageTimer = time.AfterFunc(delay, ler.flushStorageDirtyAsync)
}

func (ler *loadedExtensionRuntime) persistStorageSnapshot(storage map[string]interface{}) error {
	data, err := json.Marshal(storage)
	if err != nil { return err }
	return os.WriteFile(ler.getStoragePath(), data, 0600)
}

func (ler *loadedExtensionRuntime) flushStorageDirtyAsync() {
	if err := ler.flushStorageDirty(); err != nil {
		fmt.Printf("[Extension:%s] Storage flush error: %v\n", ler.extensionID, err)
	}
}

func (ler *loadedExtensionRuntime) flushStorageDirty() error {
	ler.storageMu.Lock()
	if ler.storageClosed { ler.storageTimer = nil; ler.storageMu.Unlock(); return nil }
	if !ler.storageDirty { ler.storageTimer = nil; ler.storageMu.Unlock(); return nil }
	snapshot := make(map[string]interface{}, len(ler.storageCache))
	for k, v := range ler.storageCache { snapshot[k] = v }
	ler.storageDirty = false
	ler.storageTimer = nil
	ler.storageMu.Unlock()
	if err := ler.persistStorageSnapshot(snapshot); err != nil {
		ler.storageMu.Lock()
		ler.storageDirty = true
		ler.queueStorageFlushLocked(storageFlushRetryDelay)
		ler.storageMu.Unlock()
		return err
	}
	return nil
}

func (ler *loadedExtensionRuntime) storageGet(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return goja.Undefined() }
	key := call.Arguments[0].String()
	if err := ler.ensureStorageLoaded(); err != nil { return goja.Undefined() }
	ler.storageMu.RLock()
	value, exists := ler.storageCache[key]
	ler.storageMu.RUnlock()
	if !exists {
		if len(call.Arguments) > 1 { return call.Arguments[1] }
		return goja.Undefined()
	}
	return ler.vm.ToValue(value)
}

func (ler *loadedExtensionRuntime) storageSet(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue(false) }
	key := call.Arguments[0].String()
	value := call.Arguments[1].Export()
	if err := ler.ensureStorageLoaded(); err != nil { return ler.vm.ToValue(false) }
	ler.storageMu.Lock()
	if ler.storageClosed { ler.storageMu.Unlock(); return ler.vm.ToValue(false) }
	if existing, exists := ler.storageCache[key]; exists {
		if fmt.Sprintf("%v", existing) == fmt.Sprintf("%v", value) { ler.storageMu.Unlock(); return ler.vm.ToValue(true) }
	}
	ler.storageCache[key] = value
	ler.storageDirty = true
	ler.queueStorageFlushLocked(ler.storageFlushDelay)
	ler.storageMu.Unlock()
	return ler.vm.ToValue(true)
}

func (ler *loadedExtensionRuntime) storageRemove(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(false) }
	key := call.Arguments[0].String()
	if err := ler.ensureStorageLoaded(); err != nil { return ler.vm.ToValue(false) }
	ler.storageMu.Lock()
	if ler.storageClosed { ler.storageMu.Unlock(); return ler.vm.ToValue(false) }
	if _, exists := ler.storageCache[key]; !exists { ler.storageMu.Unlock(); return ler.vm.ToValue(true) }
	delete(ler.storageCache, key)
	ler.storageDirty = true
	ler.queueStorageFlushLocked(ler.storageFlushDelay)
	ler.storageMu.Unlock()
	return ler.vm.ToValue(true)
}

func encryptAESGCM(plaintext, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil { return nil, err }
	gcm, err := cipher.NewGCM(block)
	if err != nil { return nil, err }
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil { return nil, err }
	return gcm.Seal(nonce, nonce, plaintext, nil), nil
}

func decryptAESGCM(ciphertext, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil { return nil, err }
	gcm, err := cipher.NewGCM(block)
	if err != nil { return nil, err }
	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize { return nil, fmt.Errorf("ciphertext too short") }
	return gcm.Open(nil, ciphertext[:nonceSize], ciphertext[nonceSize:], nil)
}

func (ler *loadedExtensionRuntime) registerCredentials() {
	credObj := ler.vm.NewObject()
	credObj.Set("store", ler.credentialsStore)
	credObj.Set("get", ler.credentialsGet)
	credObj.Set("remove", ler.credentialsRemove)
	credObj.Set("has", ler.credentialsHas)
	ler.vm.Set("credentials", credObj)
}

func (ler *loadedExtensionRuntime) getCredentialsPath() string { return filepath.Join(ler.dataDir, ".credentials.enc") }
func (ler *loadedExtensionRuntime) getSaltPath() string        { return filepath.Join(ler.dataDir, ".cred_salt") }

func (ler *loadedExtensionRuntime) getOrCreateSalt() ([]byte, error) {
	salt, err := os.ReadFile(ler.getSaltPath())
	if err == nil && len(salt) == 32 { return salt, nil }
	salt = make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil { return nil, fmt.Errorf("failed to generate salt: %w", err) }
	if err := os.WriteFile(ler.getSaltPath(), salt, 0600); err != nil { return nil, fmt.Errorf("failed to save salt: %w", err) }
	return salt, nil
}

func (ler *loadedExtensionRuntime) getEncryptionKey() ([]byte, error) {
	salt, err := ler.getOrCreateSalt()
	if err != nil { return nil, err }
	hash := sha256.Sum256(append([]byte(ler.extensionID), salt...))
	return hash[:], nil
}

func (ler *loadedExtensionRuntime) saveCredentials(creds map[string]interface{}) error {
	data, err := json.Marshal(creds)
	if err != nil { return err }
	key, err := ler.getEncryptionKey()
	if err != nil { return err }
	encrypted, err := encryptAESGCM(data, key)
	if err != nil { return err }
	return os.WriteFile(ler.getCredentialsPath(), encrypted, 0600)
}

func (ler *loadedExtensionRuntime) loadCredentials() (map[string]interface{}, error) {
	data, err := os.ReadFile(ler.getCredentialsPath())
	if err != nil {
		if os.IsNotExist(err) { return make(map[string]interface{}), nil }
		return nil, err
	}
	key, err := ler.getEncryptionKey()
	if err != nil { return nil, err }
	decrypted, err := decryptAESGCM(data, key)
	if err != nil { return nil, fmt.Errorf("failed to decrypt credentials: %w", err) }
	var creds map[string]interface{}
	if err := json.Unmarshal(decrypted, &creds); err != nil { return nil, err }
	if creds == nil { creds = make(map[string]interface{}) }
	return creds, nil
}

func (ler *loadedExtensionRuntime) credentialsStore(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "key and value required"}) }
	key := call.Arguments[0].String()
	value := call.Arguments[1].Export()
	creds, err := ler.loadCredentials()
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	creds[key] = value
	if err := ler.saveCredentials(creds); err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	return ler.vm.ToValue(map[string]interface{}{"success": true})
}
func (ler *loadedExtensionRuntime) credentialsGet(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return goja.Undefined() }
	creds, err := ler.loadCredentials()
	if err != nil { return goja.Undefined() }
	if value, exists := creds[call.Arguments[0].String()]; exists { return ler.vm.ToValue(value) }
	if len(call.Arguments) > 1 { return call.Arguments[1] }
	return goja.Undefined()
}
func (ler *loadedExtensionRuntime) credentialsRemove(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(false) }
	creds, err := ler.loadCredentials()
	if err != nil { return ler.vm.ToValue(false) }
	delete(creds, call.Arguments[0].String())
	if err := ler.saveCredentials(creds); err != nil { return ler.vm.ToValue(false) }
	return ler.vm.ToValue(true)
}
func (ler *loadedExtensionRuntime) credentialsHas(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(false) }
	creds, err := ler.loadCredentials()
	if err != nil { return ler.vm.ToValue(false) }
	_, exists := creds[call.Arguments[0].String()]
	return ler.vm.ToValue(exists)
}
