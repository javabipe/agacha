package pairing

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"sync"
	"time"
)

var (
	ErrNotFound = errors.New("codigo nao encontrado ou expirado")
	ErrFull     = errors.New("servidor ocupado")
)

// Status é o que a TV descobre ao esperar.
type Status int

const (
	Waiting Status = iota
	Paired
	Expired
)

type session struct {
	code    string
	created time.Time
	target  *Target
	done    chan struct{}
}

type offer struct {
	target  Target
	created time.Time
}

// Store guarda sessões das TVs (a TV mostra um código e espera) e ofertas dos iPads (o iPad mostra um código).
// Tudo só em memória, com validade curta; nada é gravado em disco nem registrado em log.
type Store struct {
	mu         sync.Mutex
	now        func() time.Time
	sessionTTL time.Duration
	offerTTL   time.Duration
	maxActive  int
	sessions   map[string]*session // por id
	byCode     map[string]string   // código -> id da sessão
	offers     map[string]*offer   // por código
}

// NewStore cria o armazenamento. `now` pode ser trocado nos testes.
func NewStore(now func() time.Time) *Store {
	if now == nil {
		now = time.Now
	}
	return &Store{
		now: now, sessionTTL: 10 * time.Minute, offerTTL: 10 * time.Minute, maxActive: 5000,
		sessions: map[string]*session{}, byCode: map[string]string{}, offers: map[string]*offer{},
	}
}

// NewSession abre uma sessão para uma TV: devolve o id (segredo da TV) e o código de 4 dígitos para o iPad.
func (s *Store) NewSession() (id, code string, expires time.Time, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sweepLocked()
	if len(s.sessions)+len(s.offers) >= s.maxActive {
		return "", "", time.Time{}, ErrFull
	}
	code, err = s.freshCodeLocked()
	if err != nil {
		return "", "", time.Time{}, err
	}
	raw := make([]byte, 16)
	if _, err = rand.Read(raw); err != nil {
		return "", "", time.Time{}, err
	}
	id = hex.EncodeToString(raw)
	s.sessions[id] = &session{code: code, created: s.now(), done: make(chan struct{})}
	s.byCode[code] = id
	return id, code, s.now().Add(s.sessionTTL), nil
}

// Wait espera até `maxWait` o iPad parear com a sessão. Devolve o endereço quando pareado (e consome a sessão).
func (s *Store) Wait(ctx context.Context, id string, maxWait time.Duration) (Status, *Target) {
	s.mu.Lock()
	sess, ok := s.sessions[id]
	if !ok || s.expiredLocked(sess.created, s.sessionTTL) {
		s.mu.Unlock()
		return Expired, nil
	}
	if sess.target != nil {
		target := *sess.target
		s.removeSessionLocked(id)
		s.mu.Unlock()
		return Paired, &target
	}
	done := sess.done
	s.mu.Unlock()

	timer := time.NewTimer(maxWait)
	defer timer.Stop()
	select {
	case <-done:
	case <-timer.C:
		return Waiting, nil
	case <-ctx.Done():
		return Waiting, nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	sess, ok = s.sessions[id]
	if !ok || sess.target == nil {
		return Expired, nil
	}
	target := *sess.target
	s.removeSessionLocked(id)
	return Paired, &target
}

// Pair liga o iPad à TV que mostra `code`. O código vale uma vez só.
func (s *Store) Pair(code string, target Target) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sweepLocked()
	id, ok := s.byCode[code]
	if !ok {
		return ErrNotFound
	}
	sess := s.sessions[id]
	if sess == nil || sess.target != nil {
		return ErrNotFound
	}
	sess.target = &target
	delete(s.byCode, code)
	close(sess.done)
	return nil
}

// Offer guarda o endereço do iPad e devolve o código que ele mostra (para digitar na TV).
func (s *Store) Offer(target Target) (code string, expires time.Time, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sweepLocked()
	if len(s.sessions)+len(s.offers) >= s.maxActive {
		return "", time.Time{}, ErrFull
	}
	code, err = s.freshCodeLocked()
	if err != nil {
		return "", time.Time{}, err
	}
	s.offers[code] = &offer{target: target, created: s.now()}
	return code, s.now().Add(s.offerTTL), nil
}

// Claim troca o código mostrado no iPad pelo endereço. O código vale uma vez só.
func (s *Store) Claim(code string) (Target, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sweepLocked()
	o, ok := s.offers[code]
	if !ok {
		return Target{}, ErrNotFound
	}
	delete(s.offers, code)
	return o.target, nil
}

// Active diz quantas sessões e ofertas existem agora (para testes e métricas simples).
func (s *Store) Active() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sweepLocked()
	return len(s.sessions) + len(s.offers)
}

// Sweep apaga o que expirou. Chamado de tempos em tempos.
func (s *Store) Sweep() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sweepLocked()
}

func (s *Store) expiredLocked(created time.Time, ttl time.Duration) bool {
	return s.now().Sub(created) > ttl
}

func (s *Store) sweepLocked() {
	for id, sess := range s.sessions {
		if s.expiredLocked(sess.created, s.sessionTTL) {
			s.removeSessionLocked(id)
		}
	}
	for code, o := range s.offers {
		if s.expiredLocked(o.created, s.offerTTL) {
			delete(s.offers, code)
		}
	}
}

func (s *Store) removeSessionLocked(id string) {
	if sess, ok := s.sessions[id]; ok {
		delete(s.byCode, sess.code)
		delete(s.sessions, id)
	}
}

// freshCodeLocked sorteia um código de 4 dígitos que não está em uso (por TV nem por iPad).
func (s *Store) freshCodeLocked() (string, error) {
	for range 300 {
		n, err := rand.Int(rand.Reader, big.NewInt(10000))
		if err != nil {
			return "", err
		}
		code := fmt.Sprintf("%04d", n.Int64())
		if _, used := s.byCode[code]; used {
			continue
		}
		if _, used := s.offers[code]; used {
			continue
		}
		return code, nil
	}
	return "", ErrFull
}
