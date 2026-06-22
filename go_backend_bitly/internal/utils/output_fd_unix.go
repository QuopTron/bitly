//go:build !windows

package utils

import "syscall"

func closeFD(fd int) error {
	return syscall.Close(fd)
}

func isBadFD(err error) bool {
	return err == syscall.EBADF
}
