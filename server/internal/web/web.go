// Package web embute a página que a TV abre (HTML, CSS e JavaScript simples, para TVs antigas) e a landing page.
package web

import (
	"embed"
	"io/fs"
)

//go:embed static
var files embed.FS

// A landing page (agacha.com.br) é o resultado de `astro build` (pasta site/ do repositório), copiado por site/publish.sh.
//
//go:embed all:site
var siteFiles embed.FS

// Static devolve os arquivos da página da TV.
func Static() fs.FS {
	sub, err := fs.Sub(files, "static")
	if err != nil {
		panic(err)
	}
	return sub
}

// Site devolve os arquivos da landing page do agacha.com.br.
func Site() fs.FS {
	sub, err := fs.Sub(siteFiles, "site")
	if err != nil {
		panic(err)
	}
	return sub
}
