package streaming

import (
	"sync"
	"time"
)

// decryptMemo remembers providers that resolved a track but can only serve it
// via the download() pipeline (client-side decryption required — deezer
// Blowfish FLAC). The streaming chain probes the same track in several phases
// (identifiers, ISRC, name search); once any phase confirms the verdict, the
// rest skip the provider instantly instead of burning another descriptor
// resolve. Keyed by provider+resolvedID with a short TTL.
var (
	decryptMu  sync.Mutex
	decryptMem = map[string]time.Time{}
)

const decryptMemoTTL = 90 * time.Second

func claveMemoDescifrado(name, id string) string {
	return name + "|" + id
}

func memoDescifrado(name, id string) bool {
	if name == "" || id == "" {
		return false
	}
	key := claveMemoDescifrado(name, id)
	decryptMu.Lock()
	defer decryptMu.Unlock()
	return time.Now().Before(decryptMem[key].Add(decryptMemoTTL))
}

func memoDescifradoSet(name, id string) {
	if name == "" || id == "" {
		return
	}
	key := claveMemoDescifrado(name, id)
	decryptMu.Lock()
	defer decryptMu.Unlock()
	if len(decryptMem) > 2000 {
		now := time.Now()
		for k, v := range decryptMem {
			if now.Sub(v) > decryptMemoTTL {
				delete(decryptMem, k)
			}
		}
	}
	decryptMem[key] = time.Now()
}

// classifyStreamError classifies a GetStreamURL error for the streaming chain:
//   - client-decryption means this provider can only serve the track via the
//     download() pipeline (e.g. deezer Blowfish FLAC) — abort the whole attempt
