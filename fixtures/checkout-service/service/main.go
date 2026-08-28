package main

import (
	"encoding/json"
	"net/http"
)

func health(w http.ResponseWriter, _ *http.Request) {
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func main() {
	http.HandleFunc("/health", health)
	_ = http.ListenAndServe(":8080", nil)
}
