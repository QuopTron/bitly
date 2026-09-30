package download

import (
	"sync"
	"sync/atomic"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ─────────────────────────────────────────────────────────────────────────
// memo_detalle.go — caché + single-flight de GetTrack/GetTrackByISRC.
//
// Por qué existe: las extensiones YA cachean sus getTrack (provider/metadata_cache.go,
// 10 min) pero los proveedores nativos (deezer/qobuz/tidal/youtube/…) no, y el
// camino de descarga los repite: enrichISRC hace hasta 7 GetTrack SECUENCIALES
// antes de la carrera, confirmarMatchDescarga hace otro por candidato no-dueño,
// y en la ruta de fallback (stream → descarga) todo eso vuelve a correr para la
// misma canción. Cada llamada son 200-500ms de RTT en el camino crítico.
//
// Solo se memorizan los ÉXITOS: un error (404, rate-limit, sesión vencida) no se
// retiene, así el siguiente intento vuelve a tocar al proveedor real.
// ─────────────────────────────────────────────────────────────────────────

const (
	// vidaMemoDetalle es lo que un GetTrack exitoso sirve sin volver a preguntar.
	// Corto a propósito: es metadata que puede cambiar (una sesión vencida, un
	// track retirado) y el ahorro buscado es dentro de la MISMA descarga.
	vidaMemoDetalle = 60 * time.Second
	// memoDetalleMaxEntries acota la tabla (cada entrada es un TrackResult).
	memoDetalleMaxEntries = 2048
)

// memoDetalleActivo apaga la caché para los tests del paquete (ver
// main_test.go): las pruebas crean stubs distintos con el MISMO nombre+id y sus
// afirmaciones de conteo dejarían de ser ciertas si una entrada de 60s de la
// prueba anterior les robara la llamada.
var memoDetalleActivo atomic.Bool

func init() { memoDetalleActivo.Store(true) }

// MemoDetalle activa o desactiva la caché de detalle (getTrack).
func MemoDetalle(on bool) { memoDetalleActivo.Store(on) }

type memoDetalleValor struct {
	res *provider.TrackResult
	exp time.Time
}

type memoDetalleVuelo struct {
	done chan struct{}
	res  *provider.TrackResult
	err  error
}

var (
	memoDetalleMu sync.Mutex
	memoDetalleOK = map[string]memoDetalleValor{}
	memoDetalleV  = map[string]*memoDetalleVuelo{}
)

// memoDetalle llama a p.GetTrack/metodo ([metodo] = "getTrack" o
// "getTrackByISRC") con [id], reutilizando el resultado si otra llamada para la
// misma clave ya lo trajo en los últimos vidaMemoDetalle, y colapsando los
// pedidos idénticos que corren a la vez en UNA sola consulta al proveedor.
func memoDetalle(p provider.Provider, proveedor, metodo, id string) (*provider.TrackResult, error) {
	// Sin nombre de proveedor no hay clave estable: dos stubs distintos con
	// nombre vacío compartirían entrada. Se llama directo.
	if p == nil || id == "" || proveedor == "" || !memoDetalleActivo.Load() {
		return llamarDetalle(p, metodo, id)
	}
	clave := proveedor + "\x00" + metodo + "\x00" + id

	memoDetalleMu.Lock()
	if v, ok := memoDetalleOK[clave]; ok && time.Now().Before(v.exp) {
		memoDetalleMu.Unlock()
		return v.res, nil
	}
	if w, ok := memoDetalleV[clave]; ok {
		memoDetalleMu.Unlock()
		<-w.done
		return w.res, w.err
	}
	w := &memoDetalleVuelo{done: make(chan struct{})}
	memoDetalleV[clave] = w
	memoDetalleMu.Unlock()

	res, err := llamarDetalle(p, metodo, id)

	memoDetalleMu.Lock()
	delete(memoDetalleV, clave)
	if err == nil && res != nil {
		if len(memoDetalleOK) >= memoDetalleMaxEntries {
			limpiarMemoDetalle(time.Now())
		}
		memoDetalleOK[clave] = memoDetalleValor{res: res, exp: time.Now().Add(vidaMemoDetalle)}
	}
	memoDetalleMu.Unlock()

	// Se publica DESPUÉS de escrito y el canal se cierra al final: quien espera
	// ve el resultado con la garantía de memoria del cierre.
	w.res, w.err = res, err
	close(w.done)
	return res, err
}

// llamarDetalle hace la llamada real según el método pedido.
func llamarDetalle(p provider.Provider, metodo, id string) (*provider.TrackResult, error) {
	if p == nil {
		return nil, nil
	}
	if metodo == "getTrackByISRC" {
		return p.GetTrackByISRC(id)
	}
	return p.GetTrack(id)
}

// limpiarMemoDetalle descarta primero lo vencido y, si sigue lleno, lo más
// antiguo a conveniencia (la tabla es un atajo, no una fuente de verdad).
// Debe llamarse con memoDetalleMu tomado.
func limpiarMemoDetalle(ahora time.Time) {
	for k, v := range memoDetalleOK {
		if !ahora.Before(v.exp) {
			delete(memoDetalleOK, k)
		}
	}
	for k := range memoDetalleOK {
		if len(memoDetalleOK) < memoDetalleMaxEntries {
			return
		}
		delete(memoDetalleOK, k)
	}
}
