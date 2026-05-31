//go:build windows

package gobackend

func closeFD(fd int) error {
	return nil
}

func isBadFD(err error) bool {
	return false
}
