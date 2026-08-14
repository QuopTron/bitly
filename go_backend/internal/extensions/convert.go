package extensions

import (
	"fmt"
	"math"

	"github.com/dop251/goja"
)

// ToInt64 extracts an int64 from a goja Value.
func ToInt64(v goja.Value) (int64, error) {
	if v == nil || goja.IsUndefined(v) || goja.IsNull(v) {
		return 0, fmt.Errorf("value is nil/undefined")
	}
	return v.ToInteger(), nil
}

// ToString extracts a string from a goja Value.
func ToString(v goja.Value) (string, error) {
	if v == nil || goja.IsUndefined(v) || goja.IsNull(v) {
		return "", fmt.Errorf("value is nil/undefined")
	}
	return v.String(), nil
}

// ToBool extracts a bool from a goja Value.
func ToBool(v goja.Value) (bool, error) {
	if v == nil || goja.IsUndefined(v) || goja.IsNull(v) {
		return false, fmt.Errorf("value is nil/undefined")
	}
	return v.ToBoolean(), nil
}

// ToFloat64 extracts a float64 from a goja Value.
func ToFloat64(v goja.Value) (float64, error) {
	if v == nil || goja.IsUndefined(v) || goja.IsNull(v) {
		return 0, fmt.Errorf("value is nil/undefined")
	}
	return v.ToFloat(), nil
}

// ToMap converts a goja Object to map[string]interface{}.
func ToMap(obj *goja.Object) map[string]interface{} {
	result := make(map[string]interface{})
	if obj == nil {
		return result
	}
	for _, key := range obj.Keys() {
		val := obj.Get(key)
		if val != nil {
			result[key] = exportValue(val)
		}
	}
	return result
}

// ToSlice converts a goja Array to []interface{}.
func ToSlice(arr *goja.Object) []interface{} {
	var result []interface{}
	if arr == nil {
		return result
	}
	for _, key := range arr.Keys() {
		val := arr.Get(key)
		if val != nil {
			result = append(result, exportValue(val))
		}
	}
	return result
}

// exportValue converts any goja Value to a Go value.
func exportValue(v goja.Value) interface{} {
	if v == nil || goja.IsUndefined(v) || goja.IsNull(v) {
		return nil
	}
	switch {
	case goja.IsNaN(v):
		return math.NaN()
	default:
		return v.Export()
	}
}

// ToStringMap converts a goja object to map[string]string.
func ToStringMap(obj *goja.Object) map[string]string {
	result := make(map[string]string)
	if obj == nil {
		return result
	}
	for _, key := range obj.Keys() {
		val := obj.Get(key)
		if val != nil && !goja.IsUndefined(val) && !goja.IsNull(val) {
			result[key] = val.String()
		}
	}
	return result
}
