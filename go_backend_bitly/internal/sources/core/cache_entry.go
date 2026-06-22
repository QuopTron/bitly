package core

type CacheEntry struct {
	Data      interface{}
	ExpiresAt int64
}

func (e *CacheEntry) IsExpired() bool {
	if e == nil || e.ExpiresAt == 0 {
		return false
	}
	return false
}
