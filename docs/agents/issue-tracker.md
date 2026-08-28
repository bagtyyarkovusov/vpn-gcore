# Issue tracker: GitHub

Issues and specs for this repository live in GitHub Issues. Use the `gh` CLI for operations.

## Conventions

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open`
- Comment: `gh issue comment <number> --body "..."`
- Add a label: `gh issue edit <number> --add-label "..."`
- Remove a label: `gh issue edit <number> --remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

Infer the repository from the Git remote.

## Pull requests as a triage source

PRs as a request source: no.

## Skill operations

When a skill says "publish to the issue tracker", create a GitHub issue.

When a skill says "fetch the relevant ticket", run:

`gh issue view <number> --comments`

## Parent and child issues

Use a parent issue to hold the overall plan and child issues for research, experiments, decisions, and implementation tasks.

Use native GitHub sub-issues and dependencies where available. Fall back to task lists and `Blocked by: #<number>` references when necessary.

Claim an issue with:

`gh issue edit <number> --add-assignee @me`

Resolve it by posting the result and closing it.
