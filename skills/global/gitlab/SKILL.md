---
name: gitlab
description: >
  Interact with GitLab using the `glab` CLI. Use this skill whenever the user asks to:
  list or review merge requests (MRs / PRs), check MR status, view CI/CD pipeline status,
  inspect job logs, manage issues, approve or merge MRs, view MR diffs or comments,
  check who needs to review something, or do anything GitLab-related. Trigger on phrases
  like "show my MRs", "what's the pipeline status", "list open issues", "review request",
  "check CI", "approve MR", "merge request", "GitLab", or any `glab` command intent.
---

# GitLab Skill (glab)

Use the `glab` CLI to interact with GitLab. All commands run in the current repo context unless
a `--repo OWNER/REPO` flag or `-g GROUP` flag is specified.

---

## Step 1: Understand the Request

Identify what the user wants. Map it to one of the sections below:

| User intent | Section |
|---|---|
| List/view MRs, review requests | Merge Requests |
| Check CI pipeline, job status, logs | CI/CD Pipelines |
| List/view/manage issues | Issues |
| Repo info, branches, contributors | Repository |
| Check auth / current user | Auth & Config |

If the user specifies a repo (e.g. `owner/repo` or a full URL), pass `--repo owner/repo` to all commands.

---

## Section A: Merge Requests

### List open MRs
```bash
glab mr list
```

### List all MRs (open + closed + merged)
```bash
glab mr list --all
```

### List MRs assigned to me
```bash
glab mr list --assignee=@me
```

### List MRs I need to review
```bash
glab mr list --reviewer=@me
```

### List MRs by author
```bash
glab mr list --author=<username>
```

### List draft MRs
```bash
glab mr list --draft
```

### View a specific MR (by ID or current branch)
```bash
glab mr view <id>
# or for the current branch:
glab mr view
```

### View MR with comments and discussions
```bash
glab mr view <id> --comments
```

### View only unresolved discussions
```bash
glab mr view <id> --unresolved
```

### View MR diff
```bash
glab mr diff <id>
```

### Check MR pipeline/CI status
After viewing the MR, get its source branch, then:
```bash
glab ci status --branch=<source-branch>
```

### Approve an MR
```bash
glab mr approve <id>
```

### Merge an MR
```bash
glab mr merge <id>
```

### Add a comment to an MR
```bash
glab mr note <id> --message "Your comment here"
```

### Check out an MR locally
```bash
glab mr checkout <id>
```

### Get issues linked to an MR
```bash
glab mr issues <id>
```

---

## Section B: CI/CD Pipelines

### Check pipeline status for current branch
```bash
glab ci status
```

### Check pipeline status for a specific branch
```bash
glab ci status --branch=<branch-name>
```

### List recent pipelines
```bash
glab ci list
```

### Get pipeline details as JSON
```bash
glab ci get --branch=<branch-name> --output=json
```

### View job logs (live tail)
```bash
glab job logs <job-id>
```
To find the job ID, first run `glab ci status` and note the job IDs shown.

### Retry a failed job
```bash
glab ci retry <job-id>
```

### Cancel a running pipeline
```bash
glab ci cancel
```

### Run a new pipeline on current branch
```bash
glab ci run
```

### Lint `.gitlab-ci.yml`
```bash
glab ci lint
```

---

## Section C: Issues

### List open issues
```bash
glab issue list
```

### List all issues (open + closed)
```bash
glab issue list --all
```

### List issues assigned to me
```bash
glab issue list --assignee=@me
```

### View a specific issue
```bash
glab issue view <id>
```

### View issue with comments
```bash
glab issue view <id> --comments
```

### Create an issue
```bash
glab issue create --title "Title here" --description "Description here"
```

### Add a comment to an issue
```bash
glab issue note <id> --message "Your comment here"
```

### Close an issue
```bash
glab issue close <id>
```

---

## Section D: Repository

### View repo info
```bash
glab repo view
```

### List all branches
```bash
glab repo list
```

### Open repo in browser
```bash
glab repo view --web
```

---

## Section E: Auth & Config

### Check current authenticated user and host
```bash
glab auth status
```

### Show current glab config
```bash
glab config list
```

---

## Step 2: Run the Commands

Run the relevant command(s) using the Bash tool. Parse the output and present results clearly.

**Tips:**
- Use `--output=json` on supported commands to get structured data when you need to extract specific fields.
- When showing MR lists, summarize: MR ID, title, author, target branch, status, and pipeline status.
- When showing pipeline status, highlight failing jobs and their names.
- If a command fails because glab isn't authenticated (`glab auth status`), tell the user to run `glab auth login` interactively.
- If not in a git repo, prompt for `--repo OWNER/REPO` or navigate to the right directory.

---

## Step 3: Present Results

Format output clearly:

**For MR lists:**
```
## Open Merge Requests

| # | Title | Author | Target | Status | CI |
|---|---|---|---|---|---|
| 42 | Add login feature | alice | main | Open | Passed |
| 38 | Fix null pointer | bob | develop | Draft | Running |
```

**For pipeline/CI status:**
```
## Pipeline: branch-name

Status: FAILED
Stages:
  ✅ build     — passed
  ❌ test      — FAILED
    • unit-tests (job #1234) — FAILED
    • lint (job #1235)       — passed
  ⏸️ deploy    — skipped
```

**For issues:**
```
## Open Issues

| # | Title | Author | Labels | Assignee |
|---|---|---|---|---|
| 55 | Button not working | carol | bug | alice |
```

If there are no results, say so concisely. Do not fabricate data.

---

## Useful Combined Workflows

### "Show me the status of my MRs and their pipelines"
1. `glab mr list --assignee=@me`
2. For each open MR, run `glab ci status --branch=<source-branch>`

### "What's blocking my MR from merging?"
1. `glab mr view <id> --unresolved` — shows unresolved discussions
2. `glab ci status --branch=<branch>` — shows failing CI jobs

### "Review an MR"
1. `glab mr view <id>` — read title, description, metadata
2. `glab mr view <id> --comments` — read discussion threads
3. `glab mr diff <id>` — view the diff
4. Use the `/review` skill if deep code analysis is needed
5. Optionally: `glab mr approve <id>` or `glab mr note <id> --message "..."`
