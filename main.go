package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/aemengo/buildpacks-github-feed/fetcher"
	"github.com/google/go-github/v35/github"
	"golang.org/x/oauth2"
)

func main() {
	token := os.Getenv("GITHUB_TOKEN")
	if token == "" {
		expectNoError(errors.New("Missing required env var 'GITHUB_TOKEN'"))
	}

	var (
		logger = log.New(os.Stdout, "[FEED] ", log.LstdFlags)
		ctx    = context.Background()
		ts     = oauth2.StaticTokenSource(&oauth2.Token{AccessToken: token})
		tc     = oauth2.NewClient(ctx, ts)
		client = github.NewClient(tc)
		port   = "8080"
	)

	if p := os.Getenv("PORT"); p != "" {
		port = p
	}

	logger.Println("Starting GitHub requests...")
	go fetcher.Start(ctx, client, logger)

	handleRequests()

	logger.Printf("Starting server on :%s\n", port)
	err := http.ListenAndServe(":"+port, nil)
	expectNoError(err)
}

func handleRequests() {
	http.Handle("/", http.FileServer(http.Dir("web")))
	http.HandleFunc("/data", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		switch r.Method {
		case http.MethodGet:
			json.NewEncoder(w).Encode(fetcher.Data())
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			json.NewEncoder(w).Encode(map[string]string{
				"error": fmt.Sprintf(`unsupported HTTP ction "%s": use "GET"`, r.Method),
			})
		}
	})
}

func expectNoError(err error) {
	if err != nil {
		fmt.Printf("Error: %s\n", err)
		os.Exit(1)
	}
}
