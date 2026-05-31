package gobackend

func isFDOutput(outputFD int) bool {
	return outputFD > 0
}

func closeOwnedOutputFD(outputFD int) {
	if !isFDOutput(outputFD) {
		return
	}

	if err := closeFD(outputFD); err != nil {
		if !isBadFD(err) {
			GoLog("[OutputFD] failed to close detached fd %d: %v\n", outputFD, err)
		}
		return
	}

	GoLog("[OutputFD] closed detached fd %d\n", outputFD)
}
