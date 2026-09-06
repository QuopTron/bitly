package gobackend

import "testing"

func TestQualityWantsLossless(t *testing.T) {
	for _, lossless := range []string{"FLAC", "flac", "LOSSLESS", "HI_RES", " Hi_Res "} {
		if !qualityWantsLossless(lossless) {
			t.Errorf("expected %q to be lossless", lossless)
		}
	}
	for _, lossy := range []string{"MP3_128", "128", "AAC_256", "mp3_320", ""} {
		if qualityWantsLossless(lossy) {
			t.Errorf("expected %q to be lossy", lossy)
		}
	}
}

func TestSamePath(t *testing.T) {
	if !samePath("/a/b", "/a/../a/b") {
		t.Error("expected samePath to normalize ..")
	}
	if samePath("/a/b", "/a/c") {
		t.Error("expected different paths to differ")
	}
}