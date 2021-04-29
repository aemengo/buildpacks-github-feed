package fetcher

import (
	"context"
	"github.com/aemengo/buildpacks-github-feed/models"
	"github.com/google/go-github/github"
	"log"
	"os"
	"sync"
	"time"
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

var cache []models.Model

type result struct {
	model models.Model
	err   error
}

type commentResult struct {
	issueNumber int
	comments    []*github.IssueComment
	err         error
}

func Start(ctx context.Context, client *github.Client, logger *log.Logger, sigs chan os.Signal) {
	fetch(ctx, client, logger)

	ticker := time.NewTicker(5 * time.Minute)

	for {
		select {
		case <-ticker.C:
			fetch(ctx, client, logger)
		case <-sigs:
			logger.Println("Stopping GitHub requests...")
			return
		}
	}
}

func fetch(ctx context.Context, client *github.Client, logger *log.Logger) {
	var (
		wg         sync.WaitGroup
		resultChan = make(chan result, len(repos))
	)

	wg.Add(len(repos))

	for _, repo := range repos {
		go fetchRepo(ctx, client, repo, resultChan, &wg, logger)
	}

	go func() {
		wg.Wait()
		close(resultChan)
	}()

	cache = collect(resultChan, logger)
}

func fetchRepo(ctx context.Context, client *github.Client, repo string, resultChan chan result, wg *sync.WaitGroup, logger *log.Logger) {
	defer wg.Done()

	opts := &github.IssueListByRepoOptions{
		State:       "open",
		Sort:        "comments",
		Direction:   "asc",
		ListOptions: github.ListOptions{Page: 1, PerPage: numberOfIssuesPerRepo}}

	issues, _, err := client.Issues.ListByRepo(ctx, "buildpacks", repo, opts)
	if err != nil {
		resultChan <- result{err: err}
		return
	}

	var (
		commentsWaitGroup = sync.WaitGroup{}
		commentResultChan = make(chan commentResult, len(issues))
	)

	commentsWaitGroup.Add(len(issues))

	for _, issue := range issues {
		go fetchRepoComments(ctx, client, repo, issue, commentResultChan, &commentsWaitGroup)
	}

	go func() {
		commentsWaitGroup.Wait()
		close(commentResultChan)
	}()

	resultChan <- result{model: models.Model{
		Repo:     repo,
		Issues:   issues,
		Comments: collectComments(commentResultChan, logger),
	}}
}

func fetchRepoComments(ctx context.Context, client *github.Client, repo string, issue *github.Issue, resultChan chan commentResult, wg *sync.WaitGroup) {
	defer wg.Done()

	opts := &github.IssueListCommentsOptions{
		Sort:        "created",
		ListOptions: github.ListOptions{Page: 1, PerPage: numberOfCommentsPerIssue},
	}

	cmts, _, err := client.Issues.ListComments(ctx, "buildpacks", repo, *issue.Number, opts)
	if err != nil {
		resultChan <- commentResult{err: err}
		return
	}

	resultChan <- commentResult{
		issueNumber: *issue.Number,
		comments:    cmts,
	}
}

func collect(resultChan chan result, logger *log.Logger) []models.Model {
	var ch []models.Model

	for result := range resultChan {
		if result.err != nil {
			logger.Printf("Error: %s\n", result.err)
			continue
		}

		ch = append(ch, result.model)
	}

	return ch
}

func collectComments(resultChan chan commentResult, logger *log.Logger) map[int][]*github.IssueComment {
	ch := map[int][]*github.IssueComment{}

	for result := range resultChan {
		if result.err != nil {
			logger.Printf("Error: %s\n", result.err)
			continue
		}

		ch[result.issueNumber] = result.comments
	}

	return ch
}
