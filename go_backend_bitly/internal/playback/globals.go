package playback

import "sync"

var (
	globalState *PlaybackState
	once        sync.Once
)

func Get() *PlaybackState {
	once.Do(func() {
		globalState = &PlaybackState{}
	})
	return globalState
}

func SendAction(action PlaybackAction) {
	ps := Get()
	ps.mu.Lock()
	defer ps.mu.Unlock()
	applyAction(ps, action)
}
