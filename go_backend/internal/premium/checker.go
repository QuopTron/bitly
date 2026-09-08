package premium

import (
	"fmt"
	"strings"
	"sync"
	"time"
)

// secretKey for HMAC-based code validation. Change in production.
var secretKey = []byte("bitly-premium-secret-2026")

// Checker manages premium status and code validation.
type Checker struct {
	mu          sync.RWMutex
	status      Status
	codes       []CodeEntry
	githubToken string // token personal de GitHub para el registro de códigos
}

// NewChecker creates a premium checker. Optionally loads initial codes.
func NewChecker(initialCodes []CodeEntry) *Checker {
	if initialCodes == nil {
		initialCodes = []CodeEntry{}
	}
	return &Checker{
		status: Status{IsPremium: false, Tier: "free"},
		codes:  initialCodes,
	}
}

// IsPremium returns the current premium status.
func (c *Checker) IsPremium() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.status.IsPremium
}

// Status returns a copy of the current premium status.
func (c *Checker) Status() Status {
	c.mu.RLock()
	defer c.mu.RUnlock()
	s := c.status
	s.Code = maskCode(s.Code)
	return s
}

// SetGithubToken guarda el token personal de GitHub que usa la validación
// del formato legacy (validador_app.go) para consultar el registro de códigos.
// Lo pasa Flutter al iniciar el backend (antes vivía en PremiumService Dart).
func (c *Checker) SetGithubToken(token string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.githubToken = token
}

// githubTokenValue devuelve el token actual (copia bajo lock).
func (c *Checker) githubTokenValue() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.githubToken
}

// SetPremium manually sets premium status (e.g., after login restore).
// expiresAt = 0 significa sin expiración (nunca expira).
func (c *Checker) SetPremium(isPremium bool, tier string) {
	c.SetPremiumConExpiracion(isPremium, tier, 0)
}

// SetPremiumConExpiracion igual que SetPremium pero fijando también la fecha
// de expiración en epoch seconds. Lo usa el sync drift→Go al arrancar para
// que el gate de descargas respete la expiración que el usuario tiene
// guardada localmente (CheckDownloadAllowed la valida).
func (c *Checker) SetPremiumConExpiracion(isPremium bool, tier string, expiresAt int64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.status.IsPremium = isPremium
	c.status.Tier = tier
	if isPremium {
		c.status.ExpiresAt = expiresAt
	} else {
		c.status.Tier = "free"
		c.status.Code = ""
		c.status.ExpiresAt = 0
	}
}

// ValidateCode checks if a code is valid and activates premium.
func (c *Checker) ValidateCode(code string) error {
	code = strings.TrimSpace(code)
	if code == "" {
		return fmt.Errorf("código vacío")
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	// Check against loaded codes first
	for i, entry := range c.codes {
		if entry.Code != code {
			continue
		}
		if entry.ExpiresAt > 0 && time.Now().Unix() > entry.ExpiresAt {
			return fmt.Errorf("código expirado")
		}
		if entry.MaxUses > 0 && entry.UsedCount >= entry.MaxUses {
			return fmt.Errorf("el código alcanzó su límite de usos")
		}
		c.codes[i].UsedCount++
		c.status = Status{
			IsPremium: true,
			Code:      code,
			Tier:      entry.Tier,
			ExpiresAt: entry.ExpiresAt,
		}
		return nil
	}

	// HMAC-based validation for generated codes
	if strings.HasPrefix(code, "BITLY-") {
		parts := strings.Split(code, "-")
		if len(parts) == 3 {
			payload := parts[1]
			sig := parts[2]
			if validateHMAC(payload, sig) {
				c.status = Status{
					IsPremium: true,
					Code:      code,
					Tier:      "premium",
					ExpiresAt: time.Now().Add(365 * 24 * time.Hour).Unix(),
				}
				return nil
			}
		}
		return fmt.Errorf("formato o firma de código inválido")
	}

	return fmt.Errorf("código desconocido")
}
