package fetcher

import (
	"context"
	"log"
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
			"user":                 *issue.User.Login,
			"is_pr":                issue.IsPullRequest(),
			"is_recent":            issue.CreatedAt.After(twoDaysAgo),
			"user_avatar_url":      *issue.User.AvatarURL,
			"created_at_humanized": humanize.Time(*issue.CreatedAt),
			"comments":             commentsAsData(mdl.comments[*issue.Number]),
			"reactions":            mdl.reactions[*issue.Number],
		})
	}

	return data
}

func commentsAsData(comments []comment) interface{} {
	data := []interface{}{}
	twoDaysAgo := time.Now().Add(-48 * time.Hour)

	for _, cmt := range comments {
		data = append(data, map[string]interface{}{
			"user":                 cmt.user,
			"body":                 cmt.body,
			"url":                  cmt.url,
			"is_recent":            cmt.createdAt.After(twoDaysAgo),
			"created_at_humanized": humanize.Time(cmt.createdAt),
		})
	}

	return data
}
