package extensions

import (
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/dop251/goja"
)

// deferredExt es una extensión registrada cuyo JS todavía NO se compiló.
//
// Registrar y compilar son dos momentos distintos. El arranque solo necesita
// los metadatos (manifest) para armar la lista de fuentes y sus capacidades,
// mientras que compilar el JS es lo caro: goja parsea y compila el archivo
// completo, y entre las extensiones empaquetadas eso son decenas de MB de
// asignaciones transitorias — justo mientras el sistema operativo todavía está
// inflando la app y el usuario mira el arranque. Con esta estructura el
// arranque paga solo los metadatos y cada extensión se compila la primera vez
// que alguien la usa de verdad (o en el warm-up de fondo).
type deferredExt struct {
	source  string
	extName string
	config  RuntimeConfig
	// once garantiza una sola compilación por extensión aunque dos goroutines
	// (puente nativo + descarga en segundo plano) la pidan a la vez. Nota: el
	// JS de carga NO puede volver a entrar por CallMethod en su propia
	// extensión —eso bloquearía en once.Do—, y no lo hace: los únicos
	// llamadores son los RPC y los proveedores, nunca un callback del sandbox.
	once sync.Once
	err  error
}

// Runtime executes JS extensions in a sandboxed goja environment.
type Runtime struct {
	// mu protege los dos mapas: el arranque, el warm-up de fondo y el puente
	// nativo pueden tocarlos desde goroutines distintas.
	mu        sync.Mutex
	sandboxes map[string]*Sandbox
	deferred  map[string]*deferredExt
}

// NewRuntime creates a new extension runtime.
func NewRuntime() *Runtime {
	return &Runtime{
		sandboxes: make(map[string]*Sandbox),
		deferred:  make(map[string]*deferredExt),
	}
}

// Count returns the number of extensions registered in the runtime. Cuenta las
// diferidas igual que las compiladas: para el llamador la pregunta es "¿ya hay
// extensiones en este registro?", y una registrada sin compilar ya está.
func (r *Runtime) Count() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.sandboxes)
}

// sandboxFor devuelve el sandbox registrado para [extID].
func (r *Runtime) sandboxFor(extID string) (*Sandbox, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	sb, ok := r.sandboxes[extID]
	return sb, ok
}

// RunScript loads and executes a JS extension file.
func (r *Runtime) RunScript(info *ExtensionInfo, cfg RuntimeConfig, dataDir string) (map[string]interface{}, error) {
	data, err := os.ReadFile(info.Path)
	if err != nil {
		return nil, fmt.Errorf("ext: read %s: %w", info.ID, err)
	}
	return r.RunJS(string(data), info.ID, info.Name, cfg, dataDir)
}

// RunJS compila y ejecuta [source] de inmediato. Se usa para las extensiones
// instaladas en disco (su carga es explícita y pedida por el usuario) y en
// tests; las empaquetadas entran diferidas por RegisterDeferred.
func (r *Runtime) RunJS(source, extID, extName string, cfg RuntimeConfig, dataDir string) (map[string]interface{}, error) {
	sb := newSandbox(extID, cfg, dataDir)
	out, err := sb.buildVM(source, extName)
	if err != nil {
		return nil, err
	}
	// Sin esto la extensión queda con la VM compilada pero sin marcar como
	// cargada, así que el push de ajustes la creería diferida, encolaría los
	// ajustes... y no habría compilación posterior que los drenara.
	sb.markLoadedAndDrainSettings()
	r.mu.Lock()
	r.sandboxes[extID] = sb
	r.mu.Unlock()
	return out, nil
}

// RegisterDeferred registra una extensión guardando su JS SIN compilar.
//
// Devuelve el sandbox ya creado (config, storage y sesión firmada listos) para
// que el llamador pueda colgarle datos del manifest —p. ej. el SignedSession—
// antes de que ocurra la compilación.
func (r *Runtime) RegisterDeferred(source, extID, extName string, cfg RuntimeConfig, dataDir string) *Sandbox {
	sb := newSandbox(extID, cfg, dataDir)
	r.mu.Lock()
	r.sandboxes[extID] = sb
	r.deferred[extID] = &deferredExt{source: source, extName: extName, config: cfg}
	r.mu.Unlock()
	return sb
}

// EnsureLoaded compila una extensión diferida la primera vez que alguien la
// necesita. Es idempotente y seguro entre goroutines: la compilación corre una
// sola vez y las demás esperan a que termine. Devuelve nil para una extensión
// ya compilada o que no está diferida.
func (r *Runtime) EnsureLoaded(extID string) error {
	r.mu.Lock()
	def, ok := r.deferred[extID]
	r.mu.Unlock()
	if !ok {
		return nil
	}
	def.once.Do(func() { def.err = r.compileDeferred(extID, def) })
	return def.err
}

// IsDeferred reports whether an extension is registered but not yet compiled.
func (r *Runtime) IsDeferred(extID string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	_, ok := r.deferred[extID]
	return ok
}

// compileDeferred compila el JS de una extensión diferida y aplica los ajustes
// que hayan quedado encolados por un push anterior a la compilación.
func (r *Runtime) compileDeferred(extID string, def *deferredExt) error {
	sb, ok := r.sandboxFor(extID)
	if !ok {
		return fmt.Errorf("ext %s: sin sandbox registrado", extID)
	}
	if _, err := sb.buildVM(def.source, def.extName); err != nil {
		return err
	}

	// Marcar como cargada y quedarse con lo encolado es UNA sola operación
	// atómica. Si un push de ajustes entra después, ya ve el sandbox cargado y
	// aplica initialize() directo; si entró antes, lo aplicamos acá. Sin ese
	// candado el push podía encolarse justo después de drenar y no aplicarse
	// nunca. El bucle solo repite mientras lleguen pushes nuevos.
	for settings := sb.markLoadedAndDrainSettings(); settings != nil; settings = sb.drainSettings() {
		if sb.tryLock(5 * time.Second) {
			_, _ = callMethodLocked(sb, "initialize", []interface{}{settings})
			sb.unlock()
		}
	}

	r.mu.Lock()
	delete(r.deferred, extID)
	r.mu.Unlock()
	return nil
}

// SetDataDir apunta el sandbox —y su almacén persistente— al directorio real.
//
// Se usa cuando el sandbox nació con un dataDir provisional (".", el valor con
// el que se registran las extensiones empaquetadas) y el host confirma después
// el directorio escribible. Tiene que mover las DOS cosas: si solo se cambia
// DataDir, el Store queda escribiendo en el CWD y todo lo que la extensión
// persista se pierde sin error.
func (s *Sandbox) SetDataDir(dir string) {
	if dir == "" || dir == "." {
		return
	}
	s.DataDir = dir
	if s.Store != nil {
		s.Store.Repoint(dir, s.ID)
	}
}

// newSandbox arma el sandbox sin VM: lo que no depende de haber compilado.
func newSandbox(extID string, cfg RuntimeConfig, dataDir string) *Sandbox {
	return &Sandbox{
		Config:  cfg,
		Store:   NewStorage(dataDir, extID),
		ID:      extID,
		DataDir: dataDir,
		lockCh:  make(chan struct{}, 1),
	}
}

// buildVM compila [source] dentro del sandbox y deja la VM lista. Es la única
// parte cara del arranque (goja parsea y compila todo el JS), y por eso es lo
// que se difiere.
func (s *Sandbox) buildVM(source, extName string) (map[string]interface{}, error) {
	vm := goja.New()
	vm.SetFieldNameMapper(goja.TagFieldNameMapper("json", true))
	s.VM = vm

	// Register all sandbox APIs
	registerHTTP(s)
	registerCrypto(s)
	registerStorage(s)
	registerFileOps(s)
	registerMatching(s)
	registerAuth(s)
	registerGlobal(s)
	registerSignedSession(s)

	_ = vm.Set("__ext_id", s.ID)
	_ = vm.Set("__ext_name", extName)

	out, err := ejecutarFuente(vm, s.ID, source, s.Config.TimeoutMs)
	if err != nil {
		// Una extensión que no compila no puede dejar una VM a medio armar:
		// otra goroutine la vería "cargada" y llamaría métodos que no existen.
		s.VM = nil
		return nil, err
	}
	return out, nil
}

// ejecutarFuente corre el JS con el presupuesto de tiempo del sandbox.
func ejecutarFuente(vm *goja.Runtime, extID, source string, timeoutMs int) (map[string]interface{}, error) {
	type resultado struct {
		val goja.Value
		err error
	}
	listo := make(chan resultado, 1)

	go func() {
		defer func() {
			if rec := recover(); rec != nil {
				listo <- resultado{err: fmt.Errorf("ext panic: %v", rec)}
			}
		}()
		val, err := vm.RunString(source)
		listo <- resultado{val: val, err: err}
	}()

	select {
	case res := <-listo:
		if res.err != nil {
			return nil, fmt.Errorf("ext %s: %w", extID, res.err)
		}
		if res.val != nil && res.val.Export() != nil {
			if obj, ok := res.val.Export().(map[string]interface{}); ok {
				return obj, nil
			}
		}
		return map[string]interface{}{}, nil
	case <-time.After(time.Duration(timeoutMs) * time.Millisecond):
		return nil, fmt.Errorf("ext %s: execution timeout (%dms)", extID, timeoutMs)
	}
}
