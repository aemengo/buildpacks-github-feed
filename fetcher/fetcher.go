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
	"rfcs",
	"pack",
	"lifecycle",
	"spec",
	"docs",
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

	cache = preserveOrder(collect(resultChan, logger))
}

func fetchRepo(ctx context.Context, client *github.Client, repo string, resultChan chan result, wg *sync.WaitGroup) {
	defer wg.Done()

	opts := &github.IssueListByRepoOptions{
		State:       "open",
		Sort:        "updated",
		Direction:   "desc",
		ListOptions: github.ListOptions{Page: 1, PerPage: numberOfIssuesPerRepo}}

	issues, _, err := client.Issues.ListByRepo(ctx, "buildpacks", repo, opts)
	if err != nil {
		resultChan <- result{err: err}
		return
	}

	rc := map[int]*github.Reactions{}
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

		rc[*issue.Number] = issue.Reactions
	}

	resultChan <- result{mdl: model{
		repo:     repo,
		issues:   issues,
		comments: ch,
		reactions: rc,
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

func preserveOrder(models []model) []model {
	pluck := func(repo string) (model, bool) {
		for _, m := range models {
			if m.repo == repo {
				return m, true
			}
		}

		return model{}, false
	}

	var elements []model
	for _, r := range repos {
		m, ok := pluck(r)
		if ok {
			elements = append(elements, m)
		}
	}
	return elements
}
