package utils

import (
	"encoding/json"
	"fmt"
	"strings"
)

func LogDebug(tag, format string, args ...interface{}) {
	GetLogBuffer().Add("DEBUG", tag, fmt.Sprintf(format, args...))
}

func LogInfo(tag, format string, args ...interface{}) {
	GetLogBuffer().Add("INFO", tag, fmt.Sprintf(format, args...))
}

func LogWarn(tag, format string, args ...interface{}) {
	GetLogBuffer().Add("WARN", tag, fmt.Sprintf(format, args...))
}

func LogError(tag, format string, args ...interface{}) {
	GetLogBuffer().Add("ERROR", tag, fmt.Sprintf(format, args...))
}

func GetLogs() string {
	return GetLogBuffer().GetAll()
}

func GetLogsSince(index int) string {
	entries, _ := GetLogBuffer().GetSince(index)
	jsonBytes, _ := json.Marshal(entries)
	return string(jsonBytes)
}

func ClearLogs() {
	GetLogBuffer().Clear()
}

func GetLogCount() int {
	return GetLogBuffer().Count()
}

func SetLoggingEnabled(enabled bool) {
	GetLogBuffer().SetLoggingEnabled(enabled)
}

func GoLog(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	message = strings.TrimSuffix(message, "\n")

	tag := "Go"
	level := "INFO"

	if strings.HasPrefix(message, "[") {
		endBracket := strings.Index(message, "]")
		if endBracket > 1 {
			tag = message[1:endBracket]
			message = strings.TrimSpace(message[endBracket+1:])
		}
	}

	msgLower := strings.ToLower(message)
	switch {
	case strings.Contains(msgLower, "error") || strings.Contains(msgLower, "failed"):
		level = "ERROR"
	case strings.Contains(msgLower, "warning") || strings.Contains(msgLower, "warn"):
		level = "WARN"
	case strings.Contains(msgLower, "success") || strings.Contains(msgLower, "match found"):
		level = "INFO"
	case strings.Contains(msgLower, "searching") || strings.Contains(msgLower, "trying") || strings.Contains(msgLower, "found"):
		level = "DEBUG"
	}

	GetLogBuffer().Add(level, tag, message)
}
