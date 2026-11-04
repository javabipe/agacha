// Package api expõe o roteador agacha.app: a TV mostra um código (ou recebe o do iPad) e é levada ao jogo na rede da casa.
package api

import (
	"encoding/json"
	"io/fs"
	"net"
	"net/http"
	"net/netip"
	"strings"
	"time"

	"github.com/javabipe/agacha/server/internal/pairing"
)

const (
	waitTime       = 20 * time.Second
	maxBody        = 2048
	perMinute      = time.Minute
	limitSession   = 12 // sessões novas por IP por minuto
	limitWait      = 40 // esperas por IP por minuto (a TV espera em ciclos de 20 s)
	limitAttempts  = 10 // códigos digitados (certos ou errados) por IP por minuto
	limitAppCalls  = 20 // chamadas do app por IP por minuto
	limitGlobalBad = 300
)

// Server junta o armazenamento, o limitador de pedidos e os arquivos da página da TV.
type Server struct {
	store   *pairing.Store
	limiter *pairing.Limiter
	static  fs.FS
}

func New(store *pairing.Store, limiter *pairing.Limiter, static fs.FS) http.Handler {
	s := &Server{store: store, limiter: limiter, static: static}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.page("index.html", "text/html; charset=utf-8"))
	mux.HandleFunc("GET /tv.js", s.page("tv.js", "application/javascript; charset=utf-8"))
	mux.HandleFunc("GET /tv.css", s.page("tv.css", "text/css; charset=utf-8"))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { writeJSON(w, http.StatusOK, map[string]any{"ok": true}) })
	mux.HandleFunc("POST /api/tv/session", s.newSession)
	mux.HandleFunc("GET /api/tv/wait", s.wait)
	mux.HandleFunc("POST /api/tv/claim", s.claim)
	mux.HandleFunc("POST /api/app/offer", s.offer)
	mux.HandleFunc("POST /api/app/pair", s.pair)
	return secureHeaders(redirectWWW(mux))
}

// secureHeaders põe os cabeçalhos de segurança em toda resposta (a Cloudflare está na frente, sem proxy reverso nosso).
func secureHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := w.Header()
		header.Set("Content-Security-Policy", "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
		header.Set("X-Content-Type-Options", "nosniff")
		header.Set("Referrer-Policy", "no-referrer")
		header.Set("X-Frame-Options", "DENY")
		header.Set("Cross-Origin-Opener-Policy", "same-origin")
		header.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()")
		header.Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
		next.ServeHTTP(w, r)
	})
}

// redirectWWW leva www.agacha.app (e qualquer www.) para o endereço sem www, que é o que a TV digita.
func redirectWWW(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if host := strings.ToLower(r.Host); strings.HasPrefix(host, "www.") {
			http.Redirect(w, r, "https://"+host[len("www."):]+r.URL.RequestURI(), http.StatusMovedPermanently)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ---- páginas

func (s *Server) page(name, contentType string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		data, err := fs.ReadFile(s.static, name)
		if err != nil {
			http.NotFound(w, nil)
			return
		}
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "no-cache")
		_, _ = w.Write(data)
	}
}

// ---- TV

func (s *Server) newSession(w http.ResponseWriter, r *http.Request) {
	if !s.allow(w, r, "session", limitSession) {
		return
	}
	id, code, expires, err := s.store.NewSession()
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "busy")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"session": id, "code": code, "expiresIn": int(time.Until(expires).Seconds())})
}

func (s *Server) wait(w http.ResponseWriter, r *http.Request) {
	if !s.allow(w, r, "wait", limitWait) {
		return
	}
	_ = http.NewResponseController(w).SetWriteDeadline(time.Now().Add(waitTime + 10*time.Second))
	status, target := s.store.Wait(r.Context(), r.URL.Query().Get("s"), waitTime)
	switch status {
	case pairing.Paired:
		writeJSON(w, http.StatusOK, map[string]any{"status": "paired", "url": target.URL()})
	case pairing.Waiting:
		writeJSON(w, http.StatusOK, map[string]any{"status": "waiting"})
	default:
		writeJSON(w, http.StatusNotFound, map[string]any{"status": "expired"})
	}
}

// claim: a TV digita o código que o iPad mostra.
func (s *Server) claim(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Code string `json:"code"`
	}
	if !s.decode(w, r, &body) || !s.attempt(w, r) {
		return
	}
	if !pairing.ValidCode(body.Code) {
		s.bad()
		writeError(w, http.StatusBadRequest, "invalid_code")
		return
	}
	target, err := s.store.Claim(body.Code)
	if err != nil {
		s.bad()
		writeError(w, http.StatusNotFound, "not_found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"url": target.URL()})
}

// ---- app

type targetBody struct {
	Host  string `json:"host"`
	Port  int    `json:"port"`
	Token string `json:"token"`
}

// offer: o iPad guarda o endereço e recebe um código para digitar na TV.
func (s *Server) offer(w http.ResponseWriter, r *http.Request) {
	var body targetBody
	if !s.decode(w, r, &body) || !s.allow(w, r, "app", limitAppCalls) {
		return
	}
	target, err := pairing.NewTarget(body.Host, body.Port, body.Token)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	code, expires, err := s.store.Offer(target)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "busy")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"code": code, "expiresIn": int(time.Until(expires).Seconds())})
}

// pair: o iPad digita o código que a TV mostra e entrega o endereço.
func (s *Server) pair(w http.ResponseWriter, r *http.Request) {
	var body struct {
		targetBody
		Code string `json:"code"`
	}
	if !s.decode(w, r, &body) || !s.attempt(w, r) {
		return
	}
	target, err := pairing.NewTarget(body.Host, body.Port, body.Token)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if !pairing.ValidCode(body.Code) {
		s.bad()
		writeError(w, http.StatusBadRequest, "invalid_code")
		return
	}
	if err := s.store.Pair(body.Code, target); err != nil {
		s.bad()
		writeError(w, http.StatusNotFound, "not_found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ---- utilidades

func (s *Server) decode(w http.ResponseWriter, r *http.Request, into any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, maxBody)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(into); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_body")
		return false
	}
	return true
}

func (s *Server) allow(w http.ResponseWriter, r *http.Request, bucket string, limit int) bool {
	if s.limiter.Allow(bucket+"|"+clientIP(r), limit, perMinute) {
		return true
	}
	w.Header().Set("Retry-After", "30")
	writeError(w, http.StatusTooManyRequests, "slow_down")
	return false
}

// attempt limita as tentativas de código (por IP e no total), para ninguém adivinhar os 10 mil códigos.
func (s *Server) attempt(w http.ResponseWriter, r *http.Request) bool {
	if !s.limiter.Allow("global-bad|all", limitGlobalBad, perMinute) {
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusTooManyRequests, "slow_down")
		return false
	}
	return s.allow(w, r, "attempt", limitAttempts)
}

// bad conta uma tentativa errada no limite global.
func (s *Server) bad() { s.limiter.Allow("global-bad|all", limitGlobalBad, perMinute) }

// clientIP usa o X-Forwarded-For que o Caddy escreve (um IP só) quando a conexão vem da própria máquina/rede interna.
func clientIP(r *http.Request) string {
	remote, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		remote = r.RemoteAddr
	}
	if addr, err := netip.ParseAddr(remote); err == nil && (addr.IsLoopback() || addr.IsPrivate()) {
		if forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0]); forwarded != "" {
			return forwarded
		}
	}
	return remote
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeError(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, map[string]any{"error": code})
}
