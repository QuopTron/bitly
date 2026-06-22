package utils

// IsFDOutput checks if the given output FD is valid.
func IsFDOutput(outputFD int) bool {
	return outputFD > 0
}

// CloseOwnedOutputFD closes an output FD if valid.
func CloseOwnedOutputFD(outputFD int) {
	if !IsFDOutput(outputFD) {
		return
	}
	if err := closeFD(outputFD); err != nil && !isBadFD(err) {
		LogWarn("OutputFD", "close fd %d: %v", outputFD, err)
	}
}
