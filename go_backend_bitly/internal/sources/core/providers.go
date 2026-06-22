package core

// RegisterBuiltinProviders is a placeholder — actual registration is done
// via ProviderRegistrar implementations defined in internal/sources/providers/register.go
// to avoid circular imports (core → providers/deezer → core).
type ProviderRegistrar func(registry *ProviderRegistry)
