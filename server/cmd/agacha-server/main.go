// Command agacha-server é o roteador do agacha.app: liga o navegador da TV ao jogo que roda no iPad, na rede da casa.
package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/javabipe/agacha/server/internal/api"
	"github.com/javabipe/agacha/server/internal/pairing"
	"github.com/javabipe/agacha/server/internal/web"
)

func main() {
	healthcheck := flag.Bool("healthcheck", false, "só consulta /healthz e sai (para o Docker)")
	flag.Parse()

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}
	if *healthcheck {
		os.Exit(check(addr))
	}

	store := pairing.NewStore(nil)
	limiter := pairing.NewLimiter(nil)
	server := &http.Server{
		Addr:              addr,
		Handler:           api.New(store, limiter, web.Static()),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    8 << 10,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	go sweepLoop(ctx, store, limiter)
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdown)
	}()

	log.Printf("agacha-server ouvindo em %s", addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}

func sweepLoop(ctx context.Context, store *pairing.Store, limiter *pairing.Limiter) {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			store.Sweep()
			limiter.Sweep(5 * time.Minute)
		}
	}
}

func check(addr string) int {
	host := addr
	if len(host) > 0 && host[0] == ':' {
		host = "127.0.0.1" + host
	}
	client := http.Client{Timeout: 3 * time.Second}
	response, err := client.Get("http://" + host + "/healthz")
	if err != nil || response.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
