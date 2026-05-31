//go:build !windows

package gobackend

import "syscall"

func closeFD(fd int) error {
	return syscall.Close(fd)
}

func isBadFD(err error) bool {
	return err == syscall.EBADF
}
