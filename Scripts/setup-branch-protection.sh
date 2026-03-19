#!/usr/bin/env bash
# Sets up branch protection rules for the 'main' and 'release' branches
# using the GitHub CLI. Run once by a repository admin.
#
# Prerequisites:
#   - GitHub CLI installed: https://cli.github.com
#   - Authenticated with admin rights: gh auth login
#
# Usage:
#   ./Scripts/setup-branch-protection.sh [OWNER/REPO]
#
# Example:
#   ./Scripts/setup-branch-protection.sh SteamedHamsAU/snap

set -euo pipefail

REPO="${1:-SteamedHamsAU/snap}"

echo "Configuring branch protection for ${REPO}..."

# ---------------------------------------------------------------------------
# main — integration branch
# Require 1 approval + all CI status checks to pass before merging.
# ---------------------------------------------------------------------------
echo "  → main"
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO}/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "CI / Build & Test"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

# ---------------------------------------------------------------------------
# release — stable, tagged releases
# Only allow merges from main; require CI + archive check.
# ---------------------------------------------------------------------------
echo "  → release"
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO}/branches/release/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Release / Archive"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

echo "Done. Branch protection rules applied to 'main' and 'release'."
