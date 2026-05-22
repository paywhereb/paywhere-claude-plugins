---
name: squash
description: Squash all commits on the current branch into a single commit using interactive rebase
disable-model-invocation: true
argument-hint: "[base-branch (default: master)]"
---

Squash all commits on the current branch into a single commit using git interactive rebase.

## Steps

1. **Determine the base branch**: Use `$ARGUMENTS` if provided, otherwise default to `master`. Verify the base branch exists (try `origin/<base>` if local branch doesn't exist).

2. **Verify state**: Ensure the working tree is clean (no uncommitted changes). If dirty, stop and tell the user to commit or stash first.

3. **Count commits**: Run `git rev-list --count <base>..HEAD` to find how many commits will be squashed. If there are 0 or 1 commits, inform the user there's nothing to squash and stop.

4. **Read all commit messages**: Run `git log --format="- %s%n%n%b" <base>..HEAD` to collect all commit subjects and bodies.

5. **Compose the squashed commit message**: Write a new commit message that:
   - Has a clear, concise summary line describing the overall change
   - Includes a section listing the original commits that were squashed
   - Preserves any meaningful detail from the original commit bodies
   - Format:
     ```
     <Summary of all changes>

     Squashed commits:
     - <commit message 1>
     - <commit message 2>
     ...
     ```

6. **Perform the interactive rebase**: Use `GIT_SEQUENCE_EDITOR` to automate the interactive rebase. This replaces all `pick` commands after the first with `squash`:
   ```bash
   GIT_SEQUENCE_EDITOR="sed -i '2,\$s/^pick /squash /'" git rebase -i <base>
   ```
   Then use `GIT_SEQUENCE_EDITOR` again or `git commit --amend` to set the final commit message.

   The full approach:
   ```bash
   # Step A: Squash all commits into one (auto-accept combined message)
   GIT_SEQUENCE_EDITOR="sed -i '2,\$s/^pick /squash /'" GIT_EDITOR="true" git rebase -i <base>

   # Step B: Amend the commit with the composed message
   git commit --amend -m "<composed message>"
   ```

7. **Verify**: Run `git log --oneline <base>..HEAD` to confirm there is now exactly 1 commit. Show the user the final commit message.

## Important

- Use `git rebase -i` (interactive rebase) — do NOT use soft reset or other approaches.
- NEVER force push automatically. If the branch has been pushed, inform the user they will need to force push and let them decide.
- If the rebase encounters conflicts, stop and inform the user.
