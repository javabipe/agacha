package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"testing/fstest"

	"github.com/javabipe/agacha/server/internal/pairing"
)

func newTestServer() http.Handler {
	static := fstest.MapFS{
		"index.html": {Data: []byte("<html>agacha</html>")},
		"tv.js":      {Data: []byte("//js")},
		"tv.css":     {Data: []byte("/*css*/")},
	}
	return New(pairing.NewStore(nil), pairing.NewLimiter(nil), static)
}

func call(handler http.Handler, method, path string, body any, ip string) (int, map[string]any) {
	var reader *bytes.Reader
	if body != nil {
		data, _ := json.Marshal(body)
		reader = bytes.NewReader(data)
	} else {
		reader = bytes.NewReader(nil)
	}
	request := httptest.NewRequest(method, path, reader)
	request.RemoteAddr = "172.18.0.1:5000"
	request.Header.Set("X-Forwarded-For", ip)
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	var out map[string]any
	_ = json.Unmarshal(recorder.Body.Bytes(), &out)
	return recorder.Code, out
}

func TestServesThePageAndHealth(t *testing.T) {
	handler := newTestServer()
	for path, want := range map[string]string{"/": "agacha", "/tv.js": "//js", "/tv.css": "css"} {
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, httptest.NewRequest("GET", path, nil))
		if recorder.Code != 200 || !strings.Contains(recorder.Body.String(), want) {
			t.Errorf("%s: %d %q", path, recorder.Code, recorder.Body.String())
		}
	}
	if code, _ := call(handler, "GET", "/healthz", nil, "1.1.1.1"); code != 200 {
		t.Errorf("healthz: %d", code)
	}
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest("GET", "/qualquer", nil))
	if recorder.Code != 404 {
		t.Errorf("rota desconhecida: %d", recorder.Code)
	}
}

func TestTVShowsCodeAndAppPairsIt(t *testing.T) {
	handler := newTestServer()
	code, session := call(handler, "POST", "/api/tv/session", nil, "200.1.1.1")
	if code != 200 {
		t.Fatalf("session: %d", code)
	}
	tvCode, _ := session["code"].(string)
	id, _ := session["session"].(string)
	pairCode, out := call(handler, "POST", "/api/app/pair",
		map[string]any{"code": tvCode, "host": "192.168.13.20", "port": 8080, "token": "4821"}, "200.1.1.2")
	if pairCode != 200 || out["ok"] != true {
		t.Fatalf("pair: %d %v", pairCode, out)
	}
	waitCode, wait := call(handler, "GET", "/api/tv/wait?s="+id, nil, "200.1.1.1")
	if waitCode != 200 || wait["status"] != "paired" || wait["url"] != "http://192.168.13.20:8080/?t=4821" {
		t.Fatalf("wait: %d %v", waitCode, wait)
	}
}

func TestAppOfferAndTVClaim(t *testing.T) {
	handler := newTestServer()
	code, offer := call(handler, "POST", "/api/app/offer", map[string]any{"host": "10.0.0.9", "port": 8080}, "200.1.1.2")
	if code != 200 {
		t.Fatalf("offer: %d %v", code, offer)
	}
	claimCode, claim := call(handler, "POST", "/api/tv/claim", map[string]any{"code": offer["code"]}, "200.1.1.1")
	if claimCode != 200 || claim["url"] != "http://10.0.0.9:8080/" {
		t.Fatalf("claim: %d %v", claimCode, claim)
	}
	if again, _ := call(handler, "POST", "/api/tv/claim", map[string]any{"code": offer["code"]}, "200.1.1.1"); again != 404 {
		t.Errorf("segundo claim deveria dar 404, deu %d", again)
	}
}

func TestPublicAddressesAreRefused(t *testing.T) {
	handler := newTestServer()
	for _, host := range []string{"8.8.8.8", "evil.example.com", "127.0.0.1"} {
		if code, _ := call(handler, "POST", "/api/app/offer", map[string]any{"host": host, "port": 8080}, "200.1.1.2"); code != 400 {
			t.Errorf("%s deveria dar 400, deu %d", host, code)
		}
	}
	_, session := call(handler, "POST", "/api/tv/session", nil, "200.1.1.1")
	code, _ := call(handler, "POST", "/api/app/pair",
		map[string]any{"code": session["code"], "host": "8.8.8.8", "port": 8080}, "200.1.1.2")
	if code != 400 {
		t.Errorf("pair com IP publico deveria dar 400, deu %d", code)
	}
}

func TestBodyIsStrict(t *testing.T) {
	handler := newTestServer()
	if code, _ := call(handler, "POST", "/api/tv/claim", map[string]any{"code": "1234", "extra": 1}, "200.1.1.1"); code != 400 {
		t.Errorf("campo desconhecido deveria dar 400, deu %d", code)
	}
	if code, _ := call(handler, "POST", "/api/tv/claim", map[string]any{"code": "12"}, "200.1.1.1"); code != 400 {
		t.Errorf("codigo curto deveria dar 400, deu %d", code)
	}
}

func TestGuessingCodesIsRateLimited(t *testing.T) {
	handler := newTestServer()
	limited := false
	for i := 0; i < 30; i++ {
		code, _ := call(handler, "POST", "/api/tv/claim", map[string]any{"code": "0000"}, "200.9.9.9")
		if code == 429 {
			limited = true
			break
		}
	}
	if !limited {
		t.Error("tentativas seguidas deveriam ser barradas com 429")
	}
	// outro IP continua podendo tentar
	if code, _ := call(handler, "POST", "/api/tv/claim", map[string]any{"code": "0000"}, "200.9.9.10"); code == 429 {
		t.Error("outro IP nao deveria estar barrado")
	}
}

func TestClientIPTrustsForwardedOnlyFromInternalPeers(t *testing.T) {
	internal := httptest.NewRequest("GET", "/", nil)
	internal.RemoteAddr = "172.18.0.1:1234"
	internal.Header.Set("X-Forwarded-For", "203.0.113.7")
	if got := clientIP(internal); got != "203.0.113.7" {
		t.Errorf("rede interna: %s", got)
	}
	external := httptest.NewRequest("GET", "/", nil)
	external.RemoteAddr = "198.51.100.4:1234"
	external.Header.Set("X-Forwarded-For", "203.0.113.7")
	if got := clientIP(external); got != "198.51.100.4" {
		t.Errorf("origem externa nao pode escolher o proprio IP: %s", got)
	}
}
