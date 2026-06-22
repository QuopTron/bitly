package utils

import "sync"

// Parallel executes a list of functions concurrently and waits for all to complete.
func Parallel(fns ...func()) {
	var wg sync.WaitGroup
	wg.Add(len(fns))
	for _, fn := range fns {
		go func(f func()) {
			defer wg.Done()
			f()
		}(fn)
	}
	wg.Wait()
}

// ParallelWithLimit executes functions concurrently with a concurrency limit.
func ParallelWithLimit(limit int, fns ...func()) {
	sem := make(chan struct{}, limit)
	var wg sync.WaitGroup
	for _, fn := range fns {
		wg.Add(1)
		go func(f func()) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			f()
		}(fn)
	}
	wg.Wait()
}

// MapResult is the result of a parallel map operation.
type MapResult[K comparable, V any] struct {
	Key   K
	Value V
	Err   error
}

// ParallelMap executes a function for each key concurrently and returns results.
func ParallelMap[K comparable, V any](keys []K, fn func(K) (V, error)) []MapResult[K, V] {
	results := make([]MapResult[K, V], len(keys))
	var wg sync.WaitGroup
	for i, key := range keys {
		wg.Add(1)
		go func(idx int, k K) {
			defer wg.Done()
			v, err := fn(k)
			results[idx] = MapResult[K, V]{Key: k, Value: v, Err: err}
		}(i, key)
	}
	wg.Wait()
	return results
}
