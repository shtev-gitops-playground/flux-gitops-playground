package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestColourIsStablePerVersion(t *testing.T) {
	if colourFor("1.0.0") != colourFor("1.0.0") {
		t.Fatal("same version gave different colours")
	}
	if colourFor("1.0.0") == colourFor("1.1.0") {
		t.Fatal("1.0.0 and 1.1.0 should look different")
	}
}

func TestIndexShowsVersion(t *testing.T) {
	rec := httptest.NewRecorder()
	newMux("1.2.3").ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	body := rec.Body.String()
	if !strings.Contains(body, "1.2.3") {
		t.Fatalf("body doesn't mention the version: %s", body)
	}
	if !strings.Contains(body, colourFor("1.2.3")) {
		t.Fatalf("body doesn't use the version's colour: %s", body)
	}
}

func TestHealthz(t *testing.T) {
	rec := httptest.NewRecorder()
	newMux("1.2.3").ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}
