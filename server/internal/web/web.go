// Package web embute a página que a TV abre (HTML, CSS e JavaScript simples, para TVs antigas).
package web

import (
	"embed"
	"io/fs"
)

//go:embed static
var files embed.FS

// Static devolve os arquivos da página da TV.
func Static() fs.FS {
	sub, err := fs.Sub(files, "static")
	if err != nil {
		panic(err)
	}
	return sub
}
