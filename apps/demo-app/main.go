// A tiny web page that shows which version is running, in a colour picked from the version,
// so a rollout is visible at a glance.
package main

import (
	"fmt"
	"hash/fnv"
	"html/template"
	"log"
	"net/http"
	"os"
)

// Set at build time: go build -ldflags "-X main.version=1.2.3"
var version = "dev"

var page = template.Must(template.New("index").Parse(`<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>demo-app {{.Version}}</title></head>
<body style="margin:0;min-height:100vh;display:grid;place-items:center;background:{{.Colour}};color:#fff;font-family:system-ui,sans-serif">
<main style="text-align:center">
<h1 style="font-size:4rem;margin:0">{{.Version}}</h1>
<p>served by pod {{.Pod}}</p>
</main>
</body>
</html>
`))

// colourFor turns a version into a stable, readable background colour.
func colourFor(v string) string {
	h := fnv.New32a()
	h.Write([]byte(v))
	return fmt.Sprintf("hsl(%d 70%% 35%%)", h.Sum32()%360)
}

func newMux(v string) *http.ServeMux {
	pod, _ := os.Hostname()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		data := struct {
			Version, Pod string
			Colour       template.CSS // our own value, never user input, so safe to mark as CSS
		}{v, pod, template.CSS(colourFor(v))}
		if err := page.Execute(w, data); err != nil {
			log.Printf("render: %v", err)
		}
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok\n"))
	})
	return mux
}

func main() {
	log.Printf("demo-app %s listening on :8080", version)
	log.Fatal(http.ListenAndServe(":8080", newMux(version)))
}
