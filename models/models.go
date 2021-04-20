package models

import "github.com/google/go-github/github"

type Model struct {
	Repo     string
	Issues   []*github.Issue
	Comments map[int][]*github.IssueComment
}