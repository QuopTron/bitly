package extensions

import (
	"strings"

	"github.com/dop251/goja"
)

// registerMatchObject adds match-related functions to the JS sandbox.
func registerMatchObject(vm *goja.Runtime) *goja.Object {
	matchObj := vm.NewObject()

	matchObj.Set("normalize", func(call goja.FunctionCall) goja.Value {
		text := call.Argument(0).String()
		return vm.ToValue(cleanTitle(text))
	})

	matchObj.Set("normalizeString", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		return vm.ToValue(normalizeForMatch(input))
	})

	matchObj.Set("compareStrings", func(call goja.FunctionCall) goja.Value {
		a := call.Argument(0).String()
		b := call.Argument(1).String()
		return vm.ToValue(stringSimilarity(a, b))
	})

	matchObj.Set("isrcMatch", func(call goja.FunctionCall) goja.Value {
		isrc1 := call.Argument(0).String()
		isrc2 := call.Argument(1).String()
		return vm.ToValue(strings.EqualFold(isrc1, isrc2))
	})

	matchObj.Set("titleMatch", func(call goja.FunctionCall) goja.Value {
		t1 := call.Argument(0).String()
		t2 := call.Argument(1).String()
		return vm.ToValue(cleanTitle(t1) == cleanTitle(t2))
	})

	matchObj.Set("artistMatch", func(call goja.FunctionCall) goja.Value {
		a1 := call.Argument(0).String()
		a2 := call.Argument(1).String()
		return vm.ToValue(cleanArtist(a1, a2))
	})

	matchObj.Set("durationMatch", func(call goja.FunctionCall) goja.Value {
		d1 := call.Argument(0).ToInteger()
		d2 := call.Argument(1).ToInteger()
		diff := d1 - d2
		if diff < 0 {
			diff = -diff
		}
		return vm.ToValue(diff <= 3000)
	})

	matchObj.Set("fuzzyMatch", func(call goja.FunctionCall) goja.Value {
		t1 := strings.ToLower(strings.TrimSpace(call.Argument(0).String()))
		t2 := strings.ToLower(strings.TrimSpace(call.Argument(1).String()))
		return vm.ToValue(t1 == t2 || strings.Contains(t1, t2) || strings.Contains(t2, t1))
	})

	return matchObj
}

func cleanTitle(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(strings.TrimSpace(s)) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == ' ' {
			b.WriteRune(r)
		}
	}
	return strings.TrimSpace(b.String())
}

func cleanArtist(a1, a2 string) bool {
	a1 = strings.ToLower(strings.TrimSpace(a1))
	a2 = strings.ToLower(strings.TrimSpace(a2))
	if a1 == a2 {
		return true
	}
	if strings.Contains(a1, a2) || strings.Contains(a2, a1) {
		return true
	}
	a1 = strings.TrimPrefix(a1, "the ")
	a2 = strings.TrimPrefix(a2, "the ")
	return a1 == a2
}
