package youtube

import (
	"sync"
	"time"
)

type innertubeClient struct {
	Name    string `json:"clientName"`
	Version string `json:"clientVersion"`
}

type innertubeContext struct {
	Client innertubeClient `json:"client"`
}

type searchPayload struct {
	Context innertubeContext `json:"context"`
	Query   string           `json:"query"`
}

type searchClient struct {
	Name    string
	Version string
	Key     string
}

var searchClients = []searchClient{
	{Name: "WEB", Version: "2.20220801.00.00", Key: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"},
	{Name: "WEB_REMIX", Version: "1.20250227.01.00", Key: "AIzaSyC9XL3ZjB78yOKwTtGZ1l2M2Gc0xTpU7S4"},
	{Name: "ANDROID_VR", Version: "1.65.10", Key: "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"},
	{Name: "ANDROID", Version: "20.10.38", Key: "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"},
	{Name: "IOS", Version: "19.45.4", Key: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"},
}

var searchFailureCache sync.Map

type searchFailureEntry struct {
	expiresAt time.Time
}
