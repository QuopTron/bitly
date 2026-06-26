package handlers

import (
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/auth/premium"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// RegisterPremiumHandlers registers premium-related RPC methods.
func RegisterPremiumHandlers(reg *rpc.Registry) {
	reg.Register("validarCodigoPremium", func(params map[string]interface{}) (interface{}, error) {
		code := rpc.Sp(params, "codigo")
		status, err := premium.ValidateCode(code)
		if err != nil {
			return map[string]interface{}{"valido": false, "error": err.Error()}, nil
		}
		if err := premium.CheckCodeInRegistry(code); err != nil {
			return map[string]interface{}{"valido": false, "error": err.Error()}, nil
		}
		if err := premium.MarkCodeAsUsed(code); err != nil {
			return map[string]interface{}{"valido": false, "error": fmt.Sprintf("código válido pero error al actualizar registro: %v", err)}, nil
		}
		return map[string]interface{}{
			"valido": status.IsPremium,
		}, nil
	})

	reg.Register("setGithubToken", func(params map[string]interface{}) (interface{}, error) {
		token := rpc.Sp(params, "token")
		if token == "" {
			return nil, fmt.Errorf("token requerido")
		}
		premium.SetGithubToken(token)
		return "ok", nil
	})

	reg.Register("verificarPremium", func(params map[string]interface{}) (interface{}, error) {
		isPremium := rpc.Sn(params, "is_premium") == 1
		premiumUntil := int64(rpc.Sn(params, "premium_until"))
		if premiumUntil > 0 {
			return map[string]interface{}{"valido": true}, nil
		}
		if isPremium {
			return map[string]interface{}{"valido": true}, nil
		}
		return nil, fmt.Errorf("premium requerido")
	})

	reg.Register("getPremiumStatus", func(params map[string]interface{}) (interface{}, error) {
		userID := rpc.Sp(params, "user_id")
		status, err := premium.GetStatus(userID, 0, false)
		if err != nil {
			return nil, err
		}
		return status, nil
	})
}
