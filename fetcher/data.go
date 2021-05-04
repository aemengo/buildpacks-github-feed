package fetcher

import (
	"context"
	"log"
	"sort"
	"time"

	"github.com/dustin/go-humanize"
	"github.com/google/go-github/v35/github"
)

type comment struct {
	user      string
	body      string
	url       string
	createdAt time.Time
}

type model struct {
	repo      string
	issues    []*github.Issue
	reactions map[int]*github.Reactions
	comments  map[int][]comment
	checks    map[int]*github.ListCheckRunsResults
}

var cache []model

func Start(ctx context.Context, client *github.Client, logger *log.Logger) {
	fetch(ctx, client, logger)

	for range time.NewTicker(5 * time.Minute).C {
		fetch(ctx, client, logger)
	}
}

func Data() interface{} {
	data := []interface{}{}

	for _, mdl := range cache {
		data = append(data, map[string]interface{}{
			"repo":   mdl.repo,
			"issues": issuesAsData(mdl),
		})
	}

	return data
}

func issuesAsData(mdl model) interface{} {
	data := []interface{}{}
	twoDaysAgo := time.Now().Add(-48 * time.Hour)

	for _, issue := range mdl.issues {
		data = append(data, map[string]interface{}{
			"number":               *issue.Number,
			"url":                  *issue.HTMLURL,
			"title":                *issue.Title,
			"body":                 *issue.Body,
			"user":                 *issue.User.Login,
			"is_pr":                issue.IsPullRequest(),
			"is_recent":            issue.CreatedAt.After(twoDaysAgo),
			"user_avatar_url":      *issue.User.AvatarURL,
			"created_at_humanized": humanize.Time(*issue.CreatedAt),
			"comments":             commentsAsData(mdl.comments[*issue.Number]),
			"check_suites":         checksAsData(mdl.checks[*issue.Number]),
			"reactions":            mdl.reactions[*issue.Number],
		})
	}

	return data
}

func checksAsData(results *github.ListCheckRunsResults) interface{} {
	if results == nil {
		return []interface{}{}
	}

	data := []map[string]interface{}{}

	for _, run := range results.CheckRuns {
		data = append(data, map[string]interface{}{
			"check_suite_id": *run.CheckSuite.ID,
			"id":             *run.ID,
			"status":         noPtr(run.Status),
			"conclusion":     noPtr(run.Conclusion),
		})
	}

	sort.Slice(data, func(i, j int) bool {
		return data[i]["check_suite_id"].(int64) < data[j]["check_suite_id"].(int64)
	})

	checks := []map[string]interface{}{}

	for _, datum := range data {
		if len(checks) == 0 || checks[len(checks)-1]["id"].(int64) != datum["check_suite_id"].(int64) {
			checks = append(checks, map[string]interface{}{
				"id":     datum["check_suite_id"],
				"checks": []interface{}{},
			})
		}

		checks[len(checks)-1]["checks"] = append(checks[len(checks)-1]["checks"].([]interface{}), datum)
	}

	return checks
}

func commentsAsData(comments []comment) interface{} {
	data := []interface{}{}
	oneDayAgo := time.Now().Add(-24 * time.Hour)

	for _, cmt := range comments {
		data = append(data, map[string]interface{}{
			"user":                 cmt.user,
			"body":                 cmt.body,
			"url":                  cmt.url,
			"is_recent":            cmt.createdAt.After(oneDayAgo),
			"created_at_humanized": humanize.Time(cmt.createdAt),
		})
	}

	return data
}

func noPtr(s *string) string {
	if s == nil {
		return ""
	}

	return *s
}
