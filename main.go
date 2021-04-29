package main

import (
	"context"
	"errors"
	"fmt"
	"github.com/aemengo/buildpacks-github-feed/fetcher"
	"github.com/google/go-github/github"
	"golang.org/x/oauth2"
	"log"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	token := os.Getenv("GITHUB_TOKEN")
	if token == "" {
		expectNoError(errors.New("Missing required env var 'GITHUB_TOKEN'"))
	}

	var (
		sigs   = make(chan os.Signal, 1)
		logger = log.New(os.Stdout, "[FEED] ", log.LstdFlags)
		ctx    = context.Background()
		ts     = oauth2.StaticTokenSource(&oauth2.Token{AccessToken: token})
		tc     = oauth2.NewClient(ctx, ts)
		client = github.NewClient(tc)
	)

	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	logger.Println("Starting GitHub requests...")
	fetcher.Start(ctx, client, logger, sigs)
}

func expectNoError(err error) {
	if err != nil {
		fmt.Printf("Error: %s\n", err)
		os.Exit(1)
	}
}
