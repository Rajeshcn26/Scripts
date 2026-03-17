# Delete GitHub Repositories from CSV (Ruby)

This Ruby script deletes repositories in a GitHub organization based on a CSV file (header: `name`).

It is designed with safety in mind:

- **Dry-run by default** (prints what it *would* delete)
- Requires `--execute` to perform deletions
- Requires an interactive **confirmation phrase** (unless you pass `--yes`)
- Optional **prefix safety filter** using `REPO_PREFIX` (recommended)

> Warning: Deleting a repository is permanent (unless your org has restore enabled and you act quickly). Use this script carefully.

---

## Files

- `delete_repos_from_csv.rb` — the deletion script
- `repos.csv` — input CSV with repository names

---

## CSV Format

Your CSV file must be named `repos.csv` by default and have a header `name`:

```csv
name
RTSTES.common.c.logger
RTSTES.common.c.policyparser
```

Notes:
- Values can be either `repo-name` or `org/repo-name`.  
  Example: `intcx/RTSTES.common.c.logger` is also accepted.

---

## Prerequisites

1. **Ruby installed**
   ```bash
   ruby -v
   ```

2. **GitHub token (required)**
   Set a token that has permission to delete repositories in the org `intcx`.

   If your organization enforces SSO, you may need to **authorize the token for SSO**.

### Set the token

**macOS / Linux / Git Bash**
```bash
export GITHUB_TOKEN="YOUR_TOKEN"
```

**Windows PowerShell**
```powershell
$env:GITHUB_TOKEN="YOUR_TOKEN"
```

---

## Quick Start

### 1) Dry-run (no deletions)
This prints the repositories the script would delete.

```bash
ruby delete_repos_from_csv.rb
```

### 2) Execute deletions (with confirmation prompt)
```bash
ruby delete_repos_from_csv.rb --execute
```

The script will ask you to type a confirmation phrase like:
```
DELETE intcx 312
```
(Confirmation is case-insensitive and ignores extra spaces.)

---

## Recommended: Prefix Safety Filter

If you only want to delete repos that start with `RTSTES.` (recommended for safety):

**macOS / Linux / Git Bash**
```bash
REPO_PREFIX="RTSTES." ruby delete_repos_from_csv.rb --execute
```

**Windows PowerShell**
```powershell
$env:REPO_PREFIX="RTSTES."
ruby delete_repos_from_csv.rb --execute
```

This prevents accidental deletion of repos that do not match the prefix.

---

## Dangerous Mode (No Prompt)

If you want to skip the confirmation prompt (not recommended):

```bash
ruby delete_repos_from_csv.rb --execute --yes
```

Use this only when you are 100% sure the CSV is correct.

---

## Configuration (Environment Variables)

You can override defaults:

- `ORG` (default: `intcx`)
- `FILE` (default: `repos.csv`)
- `REPO_PREFIX` (optional, recommended)
- `GITHUB_API_VERSION` (default: `2026-03-10`)

Examples:

```bash
ORG="intcx" FILE="repos.csv" ruby delete_repos_from_csv.rb
```

```bash
ORG="intcx" FILE="repos.csv" REPO_PREFIX="RTSTES." ruby delete_repos_from_csv.rb --execute
```

---

## What the Script Prints

- The org and CSV filename
- The list of repos to delete
- For each repo:
  - `OK (HTTP 204)` on successful deletion
  - `FAILED (HTTP 403/404/...)` with message on failure

At the end it prints totals:
- `Deleted: X`
- `Failed: Y`

Exit codes:
- `0` when all deletions succeed
- `3` when one or more deletions fail
- `1/2` for early aborts (missing token, bad CSV, confirmation mismatch, etc.)

---

## Troubleshooting

### HTTP 403 Forbidden
Common causes:
- Token does not have permission to delete repos
- Org policy blocks deletion
- SSO authorization is required for your token

What to do:
- Confirm you have admin rights to those repos
- Confirm the token has the required access
- If SSO is enforced, authorize the token for the org

### HTTP 404 Not Found
Common causes:
- Repo name is incorrect
- Repo already deleted
- You do not have access to that repo (GitHub may return 404 for private repos you can’t access)

---

## Safety Tips

- Always run **dry-run first**
- Use `REPO_PREFIX` whenever possible
- Start by deleting **one or two** repos to validate permissions before running the full list
