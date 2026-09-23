package extensions

import (
	"fmt"
	"time"

	"github.com/dop251/goja"
)

// CallMethod calls an exported function from an extension. Una extensión
// registrada pero todavía sin compilar (ver RegisterDeferred) se compila acá,
// en su primer uso real.
func (r *Runtime) CallMethod(extID, method string, args ...interface{}) (ret interface{}, callErr error) {
	// Recover from JS panics so they don't crash the app
	defer func() {
		if rec := recover(); rec != nil {
			callErr = fmt.Errorf("ext %s: %s panic: %v", extID, method, rec)
		}
	}()

	if err := r.EnsureLoaded(extID); err != nil {
		return nil, fmt.Errorf("ext %s: %w", extID, err)
	}

	sandbox, ok := r.sandboxFor(extID)
	if !ok {
		return nil, fmt.Errorf("ext %s not loaded", extID)
	}

	// goja is not thread-safe: a background download goroutine and a bridge-
	// thread search can hit the same extension at the same time. Serialize per
	// sandbox so concurrent calls to one extension never race on its VM.
	//
	// The lock wait is BOUNDED: a JS call stuck inside a synchronous fetch
	// (the Go bridge can't honor the JS AbortController signal, so the 15s
	// JS timeout really runs the full 30s client timeout) would otherwise
	// block every later call to this extension for the whole hang — and a
	// leaked rescue goroutine holding this mutex would deadlock the app's
	// playback RPC forever. After the wait we fail fast and let the caller's
	// cooldown skip this provider instead.
	if !sandbox.tryLock(20 * time.Second) {
		return nil, fmt.Errorf("ext %s: %s busy (previous call stuck)", extID, method)
	}
	defer sandbox.unlock()

	return callMethodLocked(sandbox, method, args)
}

// callMethodLocked es el cuerpo real de una llamada JS: exige el sandbox ya
// compilado Y con su candado tomado.
//
// Lo comparte CallMethod con la aplicación de ajustes diferidos
// (compileDeferred), que necesita llamar a initialize() sin volver a entrar por
// EnsureLoaded: hacerlo desde dentro del once.Do se bloquearía a sí mismo.
func callMethodLocked(sandbox *Sandbox, method string, args []interface{}) (interface{}, error) {
	if sandbox.VM == nil {
		return nil, fmt.Errorf("ext %s not loaded", sandbox.ID)
	}

	// Marca el inicio de ESTA llamada: utils.getResolutionRemainingMs() mide el
	// presupuesto de resolución contra este instante. Se escribe con el lock
	// tomado y lo lee la propia llamada JS, así que no necesita más sincronía.
	sandbox.callStartedAt = time.Now()

	fn := sandbox.VM.Get(method)
	if fn == nil || goja.IsUndefined(fn) {
		return nil, fmt.Errorf("ext %s: method %s not found", sandbox.ID, method)
	}

	fnCall, isFunc := goja.AssertFunction(fn)
	if !isFunc {
		return nil, fmt.Errorf("ext %s: %s is not callable", sandbox.ID, method)
	}

	jsArgs := make([]goja.Value, len(args))
	for i, arg := range args {
		jsArgs[i] = sandbox.VM.ToValue(arg)
	}

	result, err := fnCall(goja.Undefined(), jsArgs...)
	if err != nil {
		return nil, fmt.Errorf("ext %s: %s call failed: %w", sandbox.ID, method, err)
	}
	if result != nil && !goja.IsUndefined(result) && !goja.IsNull(result) {
		return result.Export(), nil
	}
	return nil, nil
}

// HasMethod reports whether an extension exports a callable [method].
//
// Compila la extensión si venía diferida: preguntar si exporta algo exige tener
// el JS ejecutado. Por eso el arranque NO usa esto para las capacidades (las
// lee del manifest) y sí las acciones que el usuario pide a mano.
func (r *Runtime) HasMethod(extID, method string) bool {
	if err := r.EnsureLoaded(extID); err != nil {
		return false
	}
	sandbox, ok := r.sandboxFor(extID)
	if !ok || sandbox.VM == nil {
		return false
	}
	sandbox.lockCh <- struct{}{}
	defer func() { <-sandbox.lockCh }()
	fn := sandbox.VM.Get(method)
	if fn == nil || goja.IsUndefined(fn) {
		return false
	}
	_, isFunc := goja.AssertFunction(fn)
	return isFunc
}

// tryLock acquires the sandbox mutex, waiting at most [d]. It returns false
// when the sandbox has been busy for too long — the previous JS call is stuck
// (a synchronous fetch the bridge can't abort) — so callers can fail fast and
// let the provider cooldown skip it instead of blocking forever.
func (s *Sandbox) tryLock(d time.Duration) bool {
	select {
	case s.lockCh <- struct{}{}:
		return true
	case <-time.After(d):
		return false
	}
}

func (s *Sandbox) unlock() {
	<-s.lockCh
}

// Sandbox returns the sandbox for a registered extension, compilada o no.
//
// Un sandbox diferido ya existe (config, storage, sesión firmada) y solo le
// falta la VM, así que las comprobaciones de estado —p. ej. si la extensión
// declara sesión firmada— siguen funcionando antes de la primera compilación.
// Para saber si además está compilada, usar [Sandbox.IsLoaded].
func (r *Runtime) Sandbox(extID string) *Sandbox {
	sb, _ := r.sandboxFor(extID)
	return sb
}

// SignedSessionSandboxIDs returns the ids of registered sandboxes that declare a
// zarz signedSession config (and therefore participate in the Cloudflare
// keepalive / provisioning passes). Pandora and other non-zarz sources are
// naturally excluded because their manifest has no signedSession block.
//
// Incluye las diferidas a propósito: el manifest ya se leyó al registrarlas, así
// que su sesión firmada está configurada desde el arranque aunque la VM todavía
// no exista.
func (r *Runtime) SignedSessionSandboxIDs() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	ids := make([]string, 0, len(r.sandboxes))
	for id, sb := range r.sandboxes {
		if sb != nil && sb.SignedSession != nil {
			ids = append(ids, id)
		}
	}
	return ids
}

// Close cleans up all sandboxes. The lock wait is bounded (a sandbox stuck in
// a synchronous JS call must not hang app shutdown forever); if it can't be
// acquired we clear the interrupt anyway and drop the sandbox.
func (r *Runtime) Close() {
	r.mu.Lock()
	sandboxes := r.sandboxes
	r.sandboxes = make(map[string]*Sandbox)
	r.deferred = make(map[string]*deferredExt)
	r.mu.Unlock()

	for _, s := range sandboxes {
		if s.tryLock(2 * time.Second) {
			// IsLoaded() (atómico) y no una lectura suelta de VM: si una
			// compilación diferida está en vuelo, el puntero se está escribiendo
			// en otra goroutine. Con la marca ya publicada, leer VM es seguro; sin
			// ella simplemente no hay nada que interrumpir.
			if s.IsLoaded() {
				s.VM.ClearInterrupt()
			}
			s.unlock()
		}
	}
}
