package pairing

import (
	"context"
	"testing"
	"time"
)

type fakeClock struct{ t time.Time }

func (c *fakeClock) now() time.Time { return c.t }

func TestNewTargetAcceptsOnlyPrivateIPv4(t *testing.T) {
	good := []string{"192.168.13.20", "10.0.0.5", "172.16.4.1", "172.31.255.1"}
	for _, host := range good {
		if _, err := NewTarget(host, 8080, ""); err != nil {
			t.Errorf("%s deveria valer: %v", host, err)
		}
	}
	bad := []string{"8.8.8.8", "127.0.0.1", "169.254.1.1", "172.32.0.1", "100.64.0.1", "::1", "fd00::1", "example.com", "", "192.168.1.1:80", "0.0.0.0"}
	for _, host := range bad {
		if _, err := NewTarget(host, 8080, ""); err == nil {
			t.Errorf("%q deveria ser recusado", host)
		}
	}
}

func TestNewTargetChecksPortAndToken(t *testing.T) {
	for _, port := range []int{0, 80, 1023, 65536, -1} {
		if _, err := NewTarget("192.168.1.2", port, ""); err == nil {
			t.Errorf("porta %d deveria ser recusada", port)
		}
	}
	for _, token := range []string{"12", "123456789", "12a4", "1 34", "../x"} {
		if _, err := NewTarget("192.168.1.2", 8080, token); err == nil {
			t.Errorf("codigo %q deveria ser recusado", token)
		}
	}
	target, err := NewTarget("192.168.1.2", 8080, "4821")
	if err != nil || target.URL() != "http://192.168.1.2:8080/?t=4821" {
		t.Errorf("url inesperada: %v %v", target.URL(), err)
	}
	plain, _ := NewTarget("10.1.1.1", 8080, "")
	if plain.URL() != "http://10.1.1.1:8080/" {
		t.Errorf("url sem codigo: %s", plain.URL())
	}
}

func TestSessionPairedByTheApp(t *testing.T) {
	store := NewStore(nil)
	id, code, _, err := store.NewSession()
	if err != nil || !ValidCode(code) {
		t.Fatalf("sessao: %v %q", err, code)
	}
	target, _ := NewTarget("192.168.13.20", 8080, "1234")
	go func() {
		time.Sleep(50 * time.Millisecond)
		if err := store.Pair(code, target); err != nil {
			t.Errorf("pair: %v", err)
		}
	}()
	status, got := store.Wait(context.Background(), id, 2*time.Second)
	if status != Paired || got == nil || got.URL() != target.URL() {
		t.Fatalf("esperava pareado, veio %v %v", status, got)
	}
	// a sessão foi consumida
	if status, _ := store.Wait(context.Background(), id, 10*time.Millisecond); status != Expired {
		t.Errorf("sessao consumida deveria estar expirada, veio %v", status)
	}
	if err := store.Pair(code, target); err != ErrNotFound {
		t.Errorf("codigo usado nao pode valer de novo: %v", err)
	}
}

func TestWaitTimesOutWithoutPairing(t *testing.T) {
	store := NewStore(nil)
	id, _, _, _ := store.NewSession()
	if status, _ := store.Wait(context.Background(), id, 30*time.Millisecond); status != Waiting {
		t.Errorf("esperava Waiting, veio %v", status)
	}
	if status, _ := store.Wait(context.Background(), "inexistente", 10*time.Millisecond); status != Expired {
		t.Errorf("sessao desconhecida deveria estar expirada")
	}
}

func TestOfferClaimIsSingleUse(t *testing.T) {
	store := NewStore(nil)
	target, _ := NewTarget("10.0.0.7", 9000, "")
	code, _, err := store.Offer(target)
	if err != nil {
		t.Fatal(err)
	}
	got, err := store.Claim(code)
	if err != nil || got != target {
		t.Fatalf("claim: %v %v", got, err)
	}
	if _, err := store.Claim(code); err != ErrNotFound {
		t.Errorf("segundo claim deveria falhar: %v", err)
	}
}

func TestEverythingExpires(t *testing.T) {
	clock := &fakeClock{t: time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)}
	store := NewStore(clock.now)
	target, _ := NewTarget("10.0.0.7", 9000, "")
	offerCode, _, _ := store.Offer(target)
	_, sessionCode, _, _ := store.NewSession()
	if store.Active() != 2 {
		t.Fatalf("ativos: %d", store.Active())
	}
	clock.t = clock.t.Add(11 * time.Minute)
	if _, err := store.Claim(offerCode); err != ErrNotFound {
		t.Errorf("oferta velha deveria sumir: %v", err)
	}
	if err := store.Pair(sessionCode, target); err != ErrNotFound {
		t.Errorf("sessao velha deveria sumir: %v", err)
	}
	if store.Active() != 0 {
		t.Errorf("deveria estar vazio, tem %d", store.Active())
	}
}

func TestCodesAreUniqueAcrossSessionsAndOffers(t *testing.T) {
	store := NewStore(nil)
	target, _ := NewTarget("10.0.0.7", 9000, "")
	seen := map[string]bool{}
	for i := 0; i < 400; i++ {
		var code string
		if i%2 == 0 {
			_, c, _, err := store.NewSession()
			if err != nil {
				t.Fatal(err)
			}
			code = c
		} else {
			c, _, err := store.Offer(target)
			if err != nil {
				t.Fatal(err)
			}
			code = c
		}
		if seen[code] {
			t.Fatalf("codigo repetido %s", code)
		}
		seen[code] = true
	}
}

func TestStoreRefusesWhenFull(t *testing.T) {
	store := NewStore(nil)
	store.maxActive = 3
	for i := 0; i < 3; i++ {
		if _, _, _, err := store.NewSession(); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, _, err := store.NewSession(); err != ErrFull {
		t.Errorf("esperava ErrFull, veio %v", err)
	}
}

func TestLimiterWindow(t *testing.T) {
	clock := &fakeClock{t: time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)}
	limiter := NewLimiter(clock.now)
	for i := 0; i < 3; i++ {
		if !limiter.Allow("ip", 3, time.Minute) {
			t.Fatalf("pedido %d deveria passar", i)
		}
	}
	if limiter.Allow("ip", 3, time.Minute) {
		t.Error("quarto pedido deveria ser barrado")
	}
	if !limiter.Allow("outro", 3, time.Minute) {
		t.Error("outro IP nao deveria ser afetado")
	}
	clock.t = clock.t.Add(61 * time.Second)
	if !limiter.Allow("ip", 3, time.Minute) {
		t.Error("na janela nova deveria passar")
	}
}
