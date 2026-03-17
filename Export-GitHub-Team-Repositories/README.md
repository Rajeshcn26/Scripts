# Export GitHub Team Repositories to CSV (Ruby)

This script fetches **all repositories assigned to a GitHub team** (handles pagination), prints the repository names to the console, and writes the results to a CSV file.

- **Org:** `intcx` (default)
- **Team slug:** `rtstes-rw` (default)
- **CSV output:** `rtstes-rw-repos.csv` (default)

---

## Files

- `export_team_repos_to_csv.rb` — Ruby script that calls GitHub REST API and writes a CSV

---

## Prerequisites

1. **Ruby installed**
   ```bash
   ruby -v
   ```

2. **GitHub token in an environment variable**
   - Create a token and ensure it has access to read team repositories in the `intcx` organization.
   - If your organization enforces SSO, you may need to **authorize the token for SSO**.

Set the token:

### macOS / Linux / Git Bash
```bash
export GITHUB_TOKEN="YOUR_TOKEN"
```

### Windows PowerShell
```powershell
$env:GITHUB_TOKEN="YOUR_TOKEN"
```

---

## Script (expected filename)

Save the Ruby code as:
- `export_team_repos_to_csv.rb`

---

## How to Run

### Basic run (defaults to ORG=intcx, TEAM_SLUG=rtstes-rw)
```bash
ruby export_team_repos_to_csv.rb
```

You should see console output like:
- `Fetched page 1: 100 repos`
- ` - intcx/some-repo`
- `Fetched page 2: ...`
- `Done. Total repos: N`
- `CSV written to: rtstes-rw-repos.csv`

---

## Output CSV

By default, the script writes: `rtstes-rw-repos.csv`

CSV columns:
- `name`
- `full_name`
- `html_url`
- `private`

---

## Configuration (Environment Variables)

You can override defaults using environment variables:

- `ORG` (default: `intcx`)
- `TEAM_SLUG` (default: `rtstes-rw`)
- `OUT_CSV` (default: `<TEAM_SLUG>-repos.csv`)
- `PER_PAGE` (default: `100`)
- `GITHUB_API_VERSION` (default: `2026-03-10`)

Example:
```bash
ORG="intcx" TEAM_SLUG="rtstes-rw" OUT_CSV="repos.csv" PER_PAGE="100" ruby export_team_repos_to_csv.rb
```

PowerShell example:
```powershell
$env:ORG="intcx"
$env:TEAM_SLUG="rtstes-rw"
$env:OUT_CSV="repos.csv"
ruby export_team_repos_to_csv.rb
```

---

## Troubleshooting

### HTTP 403 Forbidden
Common causes:
- Token lacks permission
- Org requires SSO authorization for the token
- Org policy prevents listing team repos

Fix:
- Verify token permissions
- If SSO is enabled for the org, authorize the token for the org

### HTTP 404 Not Found
Common causes:
- Wrong `ORG` or `TEAM_SLUG`
- You do not have access to the org/team with the token

Fix:
- Confirm the team slug in GitHub UI (team URL usually contains the slug)
- Confirm the token has access to the organization

---

## Notes

- Pagination is handled via GitHub’s `Link` header (`rel="next"`).
- `PER_PAGE=100` is the max page size supported by GitHub REST API for this endpoint.
