package gobackend

import (
	"log"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// obtenerFeedHome ejecuta el getHomeFeed() de una extension con timeout
// individual y reintento de sesion firmada, agregando sus secciones a [all].
func obtenerFeedHome(prov *provider.ExtensionProvider, name string, all *[]FeedSectionGo, mu *sync.Mutex, wg *sync.WaitGroup) {
	defer wg.Done()
	defer func() {
		if rec := recover(); rec != nil {
			log.Printf("[feed] %s: panic: %v", name, rec)
		}
	}()

	type feedResult struct {
		sections []provider.HomeFeedSection
		err      error
	}
	ch := make(chan feedResult, 1)
	go func() {
		secs, err := prov.GetHomeFeed()
		ch <- feedResult{sections: secs, err: err}
	}()

	var sections []provider.HomeFeedSection
	select {
	case res := <-ch:
		if res.err != nil {
			log.Printf("[feed] %s: error: %v", name, res.err)
			return
		}
		if len(res.sections) == 0 {
			// Una fuente con sesion firmada (tidal/qobuz/amazon) puede devolver
			// cero secciones si el feed dispara mientras la sesion arranca.
			// Se espera brevemente y se reintenta una vez antes de rendirse.
			if !tieneSesionFirmada(name) {
				log.Printf("[feed] %s: no sections returned", name)
				return
			}
			// Fuente con sesion firmada que devolvio vacio: se espera a que la
			// sesion este usable (el bootstrap puede seguir en vuelo) y se reintenta.
			if !waitForSignedSession(name, 6*time.Second) {
				log.Printf("[feed] %s: no sections returned (session not usable)", name)
				return
			}
			retryCh := make(chan feedResult, 1)
			go func() {
				secs, err := prov.GetHomeFeed()
				retryCh <- feedResult{sections: secs, err: err}
			}()
			select {
			case res := <-retryCh:
				if res.err == nil && len(res.sections) > 0 {
					sections = res.sections
				} else {
					log.Printf("[feed] %s: no sections after session warm", name)
					return
				}
			case <-time.After(feedSourceTimeout):
				log.Printf("[feed] %s: retry timed out after %s", name, feedSourceTimeout)
				return
			}
		} else {
			sections = res.sections
		}
	case <-time.After(feedSourceTimeout):
		log.Printf("[feed] %s: timed out after %s", name, feedSourceTimeout)
		return
	}

	mu.Lock()
	total := 0
	for _, s := range sections {
		items := make([]FeedItemGo, 0, len(s.Items))
		for _, item := range s.Items {
			coverURL := item.ThumbURL
			// Fallback: YouTube thumbnail de video ID (11 chars = video ID)
			if coverURL == "" && len(item.ItemID) == 11 {
				coverURL = "https://img.youtube.com/vi/" + item.ItemID + "/mqdefault.jpg"
			}
			// Si no hay cover, dejar vacío para que Flutter muestre placeholder
			items = append(items, FeedItemGo{
				ID:         item.ItemID,
				Type:       item.ItemType,
				Name:       item.Name,
				Artists:    item.Artists,
				DurationMs: item.DurationMs,
				AlbumID:    item.AlbumID,
				AlbumName:  item.AlbumName,
				CoverURL:   coverURL,
				Source:     prov.Name(),
			})
		}
		total += len(items)
		*all = append(*all, FeedSectionGo{
			Source:      prov.Name(),
			DisplayName: prov.Name(),
			Title:       s.Title,
			Items:       items,
		})
	}
	mu.Unlock()
	log.Printf("[feed] %s: %d sections, %d items", name, len(sections), total)
}
