package api

import (
	"context"
	"github.com/aemengo/buildpacks-github-feed/models"
	"github.com/google/go-github/github"
)

func Fetch(ctx context.Context, client *github.Client) ([]models.Model, error) {
	var (
		results                      []models.Model
		repos, listOpts, commentOpts = opts()
	)

	for _, repo := range repos {
		issues, _, err := client.Issues.ListByRepo(ctx, "buildpacks", repo, listOpts)
		if err != nil {
			return nil, err
		}

		comments := map[int][]*github.IssueComment{}

		for _, issue := range issues {
			cmts, _, _ := client.Issues.ListComments(ctx, "buildpacks", repo, *issue.Number, commentOpts)

			comments[*issue.Number] = cmts
		}

		results = append(results, models.Model{
			Repo:     repo,
			Issues:   issues,
			Comments: comments,
		})
	}

	return results, nil
}

func opts() ([]string, *github.IssueListByRepoOptions, *github.IssueListCommentsOptions) {
	return []string{
			"rfcs",
			"spec",
			"docs",
			"imgutil",
			"lifecycle",
			"pack",
		},
		&github.IssueListByRepoOptions{
			State:       "open",
			Sort:        "comments",
			Direction:   "asc",
			ListOptions: github.ListOptions{Page: 1, PerPage: 20},
		},
		&github.IssueListCommentsOptions{
			Sort:        "created",
			ListOptions: github.ListOptions{Page: 1, PerPage: 2},
		}
}
