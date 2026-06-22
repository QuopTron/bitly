package utils

import "fmt"

func FormatTrackNumber(n int) string {
	if n <= 0 {
		return ""
	}
	return fmt.Sprintf("%02d", n)
}

func FormatDiscNumber(n int) string {
	if n <= 0 {
		return ""
	}
	return fmt.Sprintf("%d", n)
}

func FormatNumberWithWidth(n int, width int) string {
	if n <= 0 || width <= 0 {
		return ""
	}
	if width <= 1 {
		return FormatRawNumber(n)
	}
	return fmt.Sprintf("%0*d", width, n)
}

func FormatRawNumber(n int) string {
	if n <= 0 {
		return ""
	}
	return fmt.Sprintf("%d", n)
}
