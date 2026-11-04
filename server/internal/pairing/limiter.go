package pairing

import (
	"sync"
	"time"
)

// Limiter conta pedidos por chave (o IP de quem pediu) em janelas fixas. Só memória.
type Limiter struct {
	mu      sync.Mutex
	now     func() time.Time
	windows map[string]*window
}

type window struct {
	start time.Time
	count int
}

func NewLimiter(now func() time.Time) *Limiter {
	if now == nil {
		now = time.Now
	}
	return &Limiter{now: now, windows: map[string]*window{}}
}

// Allow devolve false quando `key` já fez `limit` pedidos na janela `per` atual.
func (l *Limiter) Allow(key string, limit int, per time.Duration) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	w, ok := l.windows[key]
	if !ok || now.Sub(w.start) >= per {
		l.windows[key] = &window{start: now, count: 1}
		return true
	}
	if w.count >= limit {
		return false
	}
	w.count++
	return true
}

// Sweep apaga janelas velhas.
func (l *Limiter) Sweep(olderThan time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	for key, w := range l.windows {
		if now.Sub(w.start) >= olderThan {
			delete(l.windows, key)
		}
	}
}
