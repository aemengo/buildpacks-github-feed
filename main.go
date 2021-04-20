package main

import (
	"context"
	"fmt"
	"github.com/aemengo/buildpacks-github-feed/api"
	"github.com/google/go-github/github"
	"golang.org/x/oauth2"
	"os"
)

func main() {
	var (
		token  = ""
		ctx    = context.Background()
		ts     = oauth2.StaticTokenSource(&oauth2.Token{AccessToken: token})
		tc     = oauth2.NewClient(ctx, ts)
		client = github.NewClient(tc)
	)

	results, err := api.Fetch(ctx, client)
	expectNoError(err)

	var count int
	for _, result := range results {
		count += len(result.Issues)
	}
	fmt.Printf("I have %d results\n", count)
}

func expectNoError(err error) {
	if err != nil {
		fmt.Printf("Error: %s\n", err)
		os.Exit(1)
	}
}
