// Package pairing guarda, só na memória e por poucos minutos, os códigos que ligam a TV ao iPad.
package pairing

import (
	"errors"
	"net"
	"net/netip"
	"strconv"
)

// Target é o endereço do jogo na rede da casa (o servidor do iPad), mais o código de acesso da câmera.
type Target struct {
	Host  string
	Port  int
	Token string
}

var (
	ErrInvalidHost  = errors.New("host precisa ser um IPv4 da rede local (10.x, 172.16-31.x ou 192.168.x)")
	ErrInvalidPort  = errors.New("porta fora do intervalo 1024-65535")
	ErrInvalidToken = errors.New("codigo de acesso precisa ter de 4 a 8 digitos")
)

// NewTarget valida o endereço. Só IPv4 privado entra: o site nunca redireciona para fora da rede local.
func NewTarget(host string, port int, token string) (Target, error) {
	addr, err := netip.ParseAddr(host)
	if err != nil || !addr.Is4() || !addr.IsPrivate() {
		return Target{}, ErrInvalidHost
	}
	if port < 1024 || port > 65535 {
		return Target{}, ErrInvalidPort
	}
	if token != "" && !isDigits(token, 4, 8) {
		return Target{}, ErrInvalidToken
	}
	return Target{Host: addr.String(), Port: port, Token: token}, nil
}

// URL é para onde o navegador da TV vai: http://ip:porta/ (com ?t=codigo quando há código da câmera).
func (t Target) URL() string {
	url := "http://" + net.JoinHostPort(t.Host, strconv.Itoa(t.Port)) + "/"
	if t.Token != "" {
		url += "?t=" + t.Token
	}
	return url
}

func isDigits(s string, min, max int) bool {
	if len(s) < min || len(s) > max {
		return false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

// ValidCode diz se o texto parece um código de pareamento (4 dígitos).
func ValidCode(s string) bool { return isDigits(s, 4, 4) }
