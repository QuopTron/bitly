package core

// SourceManager orchestrates all registered sources.
type SourceManager struct {
	registry *ProviderRegistry
	priority []string
}

// NewSourceManager creates a new source manager.
func NewSourceManager(registry *ProviderRegistry) *SourceManager {
	return &SourceManager{
		registry: registry,
		priority: []string{"deezer", "tidal_monochrome", "qobuz_kennyy"},
	}
}

// Initialize sets up all built-in sources.
func (m *SourceManager) Initialize() error {
	return nil
}

// RegisterProviders calls the registrar function to add providers.
func (m *SourceManager) RegisterProviders(registrar ProviderRegistrar) {
	registrar(m.registry)
}

// GetPriority returns the current provider priority order.
func (m *SourceManager) GetPriority() []string {
	return m.priority
}

// SetPriority sets a custom provider priority order.
func (m *SourceManager) SetPriority(priority []string) {
	m.priority = priority
}

// GetRegistry returns the underlying provider registry.
func (m *SourceManager) GetRegistry() *ProviderRegistry {
	return m.registry
}
