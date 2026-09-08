package cache

import (
	"sync"
	"time"
)

// TrackRef stores minimal track info keyed by ISRC for dedup.
type TrackRef struct {
	TrackID    string `json:"trackId"`
	Title      string `json:"title"`
	ArtistName string `json:"artistName"`
	AlbumName  string `json:"albumName"`
	Provider   string `json:"provider"`
}

// statsArchivo guarda metadata de archivo para la reconstrucción incremental.
type statsArchivo struct {
	tamano  int64
	horaMod time.Time
}

// ISRCIndex es un mapa thread-safe de ISRC → TrackRef para dedup, con
// escaneo paralelo y soporte de reconstrucción incremental.
type ISRCIndex struct {
	mutex              sync.RWMutex
	indiceISRC         map[string]*TrackRef
	cacheArchivos      map[string]statsArchivo // ruta → tamaño+horaMod para incremental
	mutexRebuild       sync.Mutex
	reconstruyendo     bool
	ultimaConstruccion time.Time
}

// NewISRCIndex crea un índice ISRC vacío.
func NewISRCIndex() *ISRCIndex {
	return &ISRCIndex{
		indiceISRC:    make(map[string]*TrackRef),
		cacheArchivos: make(map[string]statsArchivo),
	}
}

// Add guarda una referencia de track por su código ISRC.
func (idx *ISRCIndex) Add(isrc string, ref *TrackRef) {
	if isrc == "" {
		return
	}
	idx.mutex.Lock()
	idx.indiceISRC[isrc] = ref
	idx.mutex.Unlock()
}

// Lookup devuelve la referencia de track para un ISRC, si está indexado.
func (idx *ISRCIndex) Lookup(isrc string) (*TrackRef, bool) {
	if isrc == "" {
		return nil, false
	}
	idx.mutex.RLock()
	ref, ok := idx.indiceISRC[isrc]
	idx.mutex.RUnlock()
	if !ok {
		return nil, false
	}
	return ref, true
}

// Has devuelve true si el ISRC ya está indexado.
func (idx *ISRCIndex) Has(isrc string) bool {
	if isrc == "" {
		return false
	}
	idx.mutex.RLock()
	_, ok := idx.indiceISRC[isrc]
	idx.mutex.RUnlock()
	return ok
}

// Remove elimina una entrada ISRC.
func (idx *ISRCIndex) Remove(isrc string) {
	if isrc == "" {
		return
	}
	idx.mutex.Lock()
	delete(idx.indiceISRC, isrc)
	idx.mutex.Unlock()
}

// Clear elimina todas las entradas.
func (idx *ISRCIndex) Clear() {
	idx.mutex.Lock()
	idx.indiceISRC = make(map[string]*TrackRef)
	idx.cacheArchivos = make(map[string]statsArchivo)
	idx.mutex.Unlock()
}

// Len devuelve el número de ISRCs indexados.
func (idx *ISRCIndex) Len() int {
	idx.mutex.RLock()
	defer idx.mutex.RUnlock()
	return len(idx.indiceISRC)
}
