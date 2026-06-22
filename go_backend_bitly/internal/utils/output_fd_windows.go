//go:build windows

package utils

func closeFD(fd int) error {
	return nil
}

func isBadFD(err error) bool {
	return false
}
