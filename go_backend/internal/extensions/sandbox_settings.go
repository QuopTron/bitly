package extensions

// Ajustes diferidos.
//
// El push de ajustes (initialize) es la otra mitad del arranque diferido: la
// app empuja credenciales apenas Flutter está listo, y exigir que la extensión
// esté compilada para aceptarlas anularía el ahorro —cada push compilaría su
// extensión—. En vez de eso los ajustes se encolan y se aplican en la misma
// operación en que la extensión queda compilada: exactamente el orden que
// tendrían si initialize() se hubiera llamado antes de cualquier uso real.

// QueueSettings encola los ajustes de una extensión que todavía no se compiló.
// Devuelve true cuando la extensión YA está compilada, y entonces el llamador
// debe aplicar initialize() directamente.
//
// La decisión se toma bajo el mismo candado que la transición a "compilada",
// así que no queda un hueco entre "no está lista, la encolo" y "ya se compiló
// y nadie va a drenar lo encolado".
func (s *Sandbox) QueueSettings(settings map[string]string) bool {
	if s == nil {
		return false
	}
	s.settingsMu.Lock()
	defer s.settingsMu.Unlock()
	if s.vmReady.Load() {
		return true
	}
	s.pendingSettings = copiarAjustes(settings)
	return false
}

// IsLoaded reports whether the sandbox's JS has been compiled and is usable.
// Es la comprobación que reemplaza a leer [Sandbox.VM] desde fuera del paquete:
// la compilación puede ocurrir en otra goroutine (warm-up), y leer el puntero
// suelto sería una carrera.
func (s *Sandbox) IsLoaded() bool {
	return s != nil && s.vmReady.Load()
}

// markLoadedAndDrainSettings marca la VM como usable y se lleva lo que hubiera
// encolado, todo bajo el mismo candado.
func (s *Sandbox) markLoadedAndDrainSettings() map[string]string {
	s.settingsMu.Lock()
	defer s.settingsMu.Unlock()
	s.vmReady.Store(true)
	return s.drainLocked()
}

// drainSettings se lleva un push que haya llegado durante la compilación.
func (s *Sandbox) drainSettings() map[string]string {
	s.settingsMu.Lock()
	defer s.settingsMu.Unlock()
	return s.drainLocked()
}

func (s *Sandbox) drainLocked() map[string]string {
	out := s.pendingSettings
	s.pendingSettings = nil
	return out
}

func copiarAjustes(settings map[string]string) map[string]string {
	copia := make(map[string]string, len(settings))
	for k, v := range settings {
		copia[k] = v
	}
	return copia
}
