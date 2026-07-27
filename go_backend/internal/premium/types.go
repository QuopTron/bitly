package premium

// Status holds the current premium state.
type Status struct {
	IsPremium bool   `json:"isPremium"`
	Code      string `json:"code,omitempty"`
	Tier      string `json:"tier,omitempty"` // "free", "premium", "lifetime"
	ExpiresAt int64  `json:"expiresAt,omitempty"`
}

// CodeEntry is a valid premium code loaded at init or via API.
type CodeEntry struct {
	Code      string `json:"code"`
	Tier      string `json:"tier"`
	ExpiresAt int64  `json:"expiresAt,omitempty"` // 0 = never
	MaxUses   int    `json:"maxUses,omitempty"`   // 0 = unlimited
	UsedCount int    `json:"usedCount,omitempty"`
}
