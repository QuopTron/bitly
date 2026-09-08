package extensions

import "strings"

func verificarDominio(s *Sandbox, url string) error {
	if len(s.Config.AllowedDomains) == 0 {
		return nil
	}
	for _, domain := range s.Config.AllowedDomains {
		if strings.Contains(url, domain) {
			return nil
		}
	}
	return errDominioBloqueado(url)
}

func errDominioBloqueado(url string) error {
	return &extError{msg: "domain not allowed: " + url}
}

type extError struct{ msg string }

func (e *extError) Error() string { return e.msg }

func toString(v interface{}) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}
