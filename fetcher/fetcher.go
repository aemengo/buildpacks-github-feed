package fetcher

import (
	"context"
	"github.com/google/go-github/github"
	"log"
	"sort"
	"sync"
)

const (
	numberOfIssuesPerRepo    = 5
	numberOfCommentsPerIssue = 2
)

var repos = []string{
	"pack",
	"lifecycle",
	"rfcs",
	"spec",
	"docs",
	"imgutil",
}

type result struct {
	mdl model
	err error
}

func fetch(ctx context.Context, client *github.Client, logger *log.Logger) {
	var (
		wg         sync.WaitGroup
		resultChan = make(chan result, len(repos))
	)

	wg.Add(len(repos))

	for _, repo := range repos {
		go fetchRepo(ctx, client, repo, resultChan, &wg)
	}

	go func() {
		wg.Wait()
		close(resultChan)
	}()

	cache = collect(resultChan, logger)
}

func fetchRepo(ctx context.Context, client *github.Client, repo string, resultChan chan result, wg *sync.WaitGroup) {
	defer wg.Done()

	opts := &github.IssueListByRepoOptions{
		State:       "open",
		Sort:        "comments",
		Direction:   "desc",
		ListOptions: github.ListOptions{Page: 1, PerPage: numberOfIssuesPerRepo}}

	issues, _, err := client.Issues.ListByRepo(ctx, "buildpacks", repo, opts)
	if err != nil {
		resultChan <- result{err: err}
		return
	}

	ch := map[int][]*github.IssueComment{}

	for _, issue := range issues {
		cmts, _, err := client.Issues.ListComments(ctx, "buildpacks", repo, *issue.Number, nil)
		if err != nil {
			resultChan <- result{err: err}
			continue
		}

		// The GitHub API doesn't filter/sort comments appropriately
		// So it's being done client-side
		sort.Slice(cmts, func(i, j int) bool {
			return cmts[i].CreatedAt.After(*cmts[j].CreatedAt)
		})

		ch[*issue.Number] = first(numberOfCommentsPerIssue, cmts)
	}

	resultChan <- result{mdl: model{
		repo:     repo,
		issues:   issues,
		comments: ch,
	}}
}

func collect(resultChan chan result, logger *log.Logger) []model {
	var ch []model

	for r := range resultChan {
		if r.err != nil {
			logger.Printf("Error: %s\n", r.err)
			continue
		}

		ch = append(ch, r.mdl)
	}

	return ch
}

func first(count int, cmts []*github.IssueComment) []*github.IssueComment {
	var r []*github.IssueComment

	for i, cmt := range cmts {
		if i == count {
			return r
		}

		r = append(r, cmt)
	}

	return r
}
