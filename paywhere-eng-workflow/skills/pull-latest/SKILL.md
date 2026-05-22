---
name: pull-latest
description: Checkout the default branch (master or main) and pull latest from origin
disable-model-invocation: true
---

Checkout the repo's default branch and pull the latest changes from origin.

## Steps

1. **Determine the default branch**: Run `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'` to detect the default branch name. If that fails, check which of `main` or `master` exists locally or as a remote tracking branch, and use that. If neither can be found, stop and ask the user.

2. **Check for uncommitted changes**: Run `git status --porcelain`. If there are uncommitted changes, warn the user and stop. Do NOT proceed — let them decide whether to stash, commit, or discard.

3. **Checkout the default branch**: Run `git checkout <branch>`.

4. **Pull latest**: Run `git pull origin <branch>`.

5. **Confirm**: Show the user the current branch and the latest commit (`git log --oneline -1`).
