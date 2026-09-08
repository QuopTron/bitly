package download

import (
	"log"
)

func (t *Tracker) SetError(itemID, errMsg string) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		if p.Status == StatusCompleted {
			log.Printf("[tracker] SetError(%s, %s) BLOCKED (completed, path=%s)", itemID, errMsg, p.OutputPath)
			t.mu.Unlock()
			return
		}
		log.Printf("[tracker] SetError(%s, %s) prevStatus=%v outputPath=%s", itemID, errMsg, p.Status, p.OutputPath)
		p.Status = StatusFailed
		p.Error = errMsg
	} else {
		log.Printf("[tracker] SetError(%s, %s) — item NOT found!", itemID, errMsg)
	}
	t.mu.Unlock()
}

// SetOutputPath sets the final file path.
// If el item es ya marked como encrypted (un higher-calidad proveedor// already won the race), do NOT overwrite — a last-resort provider
// (soundcloud) finalizing later would replace the encrypted FLAC path
// with an MP3, causing the client-side decrypt to fail on the wrong file.
func (t *Tracker) SetOutputPath(itemID, path string) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		if p.Encrypted && p.DecryptionKey != "" {
			// Un proveedor exacto (amazon/qobuz) ya establecio una salida
			// encriptada. Un proveedor de ultimo recurso que finalice despues NO
			// debe sobrescribir la ruta — conservar el archivo encriptado para
			// que el cliente pueda descifrarlo. Solo actualizar el estado.
			log.Printf("[tracker] SetOutputPath(%s, %s) BLOCKED (encrypted already set)", itemID, path)
			p.Status = StatusCompleted
			p.Progress = 1.0
		} else {
			log.Printf("[tracker] SetOutputPath(%s, %s)", itemID, path)
			p.OutputPath = path
			p.Status = StatusCompleted
			p.Progress = 1.0
		}
	} else {
		log.Printf("[tracker] SetOutputPath(%s, %s) — item NOT found in tracker!", itemID, path)
	}
	t.mu.Unlock()
}

// SetEncryptedOutput marks the item completed with an encrypted/DRM file that
// el cliente debe decrypt (ffmpeg-kit) antes reproducción — usado cuando el backend// has no CLI ffmpeg to decrypt it (e.g. Android).
func (t *Tracker) SetEncryptedOutput(itemID, path, key, ext, inFmt string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if p, ok := t.items[itemID]; ok {
		p.OutputPath = path
		p.Status = StatusCompleted
		p.Progress = 1.0
		p.Encrypted = true
		p.ClientDecrypt = true
		p.DecryptionKey = key
		p.OutputExtension = ext
		p.InputFormat = inFmt
	}
}

// Obtiene devuelve progress para un item.
