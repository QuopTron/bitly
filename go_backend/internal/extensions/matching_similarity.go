package extensions

import (
	"fmt"
	"math/rand"
	"strings"
	"unicode"

	"github.com/dop251/goja"
)

// registerUtilsObject adds utility functions to the JS utils object.
func registerUtilsObject(vm *goja.Runtime, id string) *goja.Object {
	utilsObj := vm.NewObject()
	if existing := vm.Get("utils"); existing != nil && !goja.IsUndefined(existing) {
		if obj, ok := existing.(*goja.Object); ok {
			utilsObj = obj
		}
	}

	var userAgents = []string{
		"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
		"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
		"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
		"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
		"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
	}

	utilsObj.Set("randomUserAgent", func() string {
		return userAgents[rand.Intn(len(userAgents))]
	})

	utilsObj.Set("appUserAgent", func() string {
		return "SpotiFLAC-Mobile/" + id
	})

	utilsObj.Set("normalizeString", func(call goja.FunctionCall) goja.Value {
		input := call.Argument(0).String()
		return vm.ToValue(normalizeForMatch(input))
	})

	utilsObj.Set("compareStrings", func(call goja.FunctionCall) goja.Value {
		a := call.Argument(0).String()
		b := call.Argument(1).String()
		return vm.ToValue(stringSimilarity(a, b))
	})

	utilsObj.Set("generateSignature", func(call goja.FunctionCall) goja.Value {
		data := call.Argument(0).String()
		return vm.ToValue(fmt.Sprintf("sig_%x", []byte(data)))
	})

	vm.Set("utils", utilsObj)
	return utilsObj
}

func normalizeForMatch(s string) string {
	var result strings.Builder
	for _, r := range strings.ToLower(s) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			result.WriteRune(r)
		}
	}
	return result.String()
}

func stringSimilarity(a, b string) float64 {
	if a == b {
		return 1.0
	}
	if len(a) == 0 || len(b) == 0 {
		return 0.0
	}

	la, lb := len(a), len(b)
	if la > lb {
		a, b = b, a
		la, lb = lb, la
	}

	prev := make([]int, la+1)
	curr := make([]int, la+1)
	for i := range prev {
		prev[i] = i
	}

	for j := 1; j <= lb; j++ {
		curr[0] = j
		for i := 1; i <= la; i++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			min := prev[i] + 1
			if curr[i-1]+1 < min {
				min = curr[i-1] + 1
			}
			if prev[i-1]+cost < min {
				min = prev[i-1] + cost
			}
			curr[i] = min
		}
		prev, curr = curr, prev
	}

	distance := prev[la]
	maxLen := la
	if lb > maxLen {
		maxLen = lb
	}
	if maxLen == 0 {
		return 1.0
	}
	return 1.0 - float64(distance)/float64(maxLen)
}
