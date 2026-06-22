package core

import (
	"context"
	"fmt"
)

// DownloadResult is the result of a successful download.
type DownloadResult struct {
	FilePath string `json:"file_path"`
	Provider string `json:"provider"`
	Quality  string `json:"quality"`
	Format   string `json:"format"`
}

// FallbackManager tries multiple sources in order until one succeeds.
type FallbackManager struct {
	registry *ProviderRegistry
	priority []string
}

// NewFallbackManager creates a new fallback manager.
func NewFallbackManager(registry *ProviderRegistry, priority []string) *FallbackManager {
	return &FallbackManager{
		registry: registry,
		priority: priority,
	}
}

// DownloadWithFallback attempts to download from each provider in priority order.
func (f *FallbackManager) DownloadWithFallback(ctx context.Context, trackID, preferredQuality string) (*DownloadResult, error) {
	for _, providerID := range f.priority {
		provider := f.registry.GetDownloadProvider(providerID)
		if provider == nil {
			continue
		}
		data, err := provider.Download(trackID, preferredQuality)
		if err == nil && len(data) > 0 {
			return &DownloadResult{
				FilePath: string(data),
				Provider: providerID,
				Quality:  preferredQuality,
			}, nil
		}
	}
	return nil, fmt.Errorf("all providers failed for track %s", trackID)
}
