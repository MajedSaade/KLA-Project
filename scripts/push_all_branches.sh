#!/usr/bin/env bash
#
# push_all_branches.sh — Create a GitHub repo (if needed) and push all branches.
#
# Usage:
#   ./scripts/push_all_branches.sh [REPO_DIR] [GITHUB_REPO]
#
# Examples:
#   ./scripts/push_all_branches.sh ./complex-test-repo majedsaade/kla-complex-test-repo
#   GITHUB_TOKEN=ghp_xxx ./scripts/push_all_branches.sh
#
# GITHUB_REPO defaults to ${GITHUB_USER}/kla-complex-test-repo or prompts.
#

set -euo pipefail

REPO_DIR="${1:-./complex-test-repo}"
GITHUB_REPO="${2:-}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "Error: ${REPO_DIR} is not a Git repository." >&2
  exit 1
fi

cd "${REPO_DIR}"

if [[ -z "${GITHUB_REPO}" ]]; then
  if [[ -n "${GITHUB_USER:-}" ]]; then
    GITHUB_REPO="${GITHUB_USER}/kla-complex-test-repo"
  else
    GITHUB_USER="$(git config --global github.user 2>/dev/null || true)"
    if [[ -z "${GITHUB_USER}" ]]; then
      GITHUB_USER="$(git config --global user.name 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]' || true)"
    fi
    GITHUB_REPO="${GITHUB_USER}/kla-complex-test-repo"
  fi
fi

REMOTE_URL="https://github.com/${GITHUB_REPO}.git"
SSH_REMOTE="git@github.com:${GITHUB_REPO}.git"

echo "Target GitHub repository: ${GITHUB_REPO}"
echo "Local repository       : $(pwd)"
echo ""

create_github_repo() {
  if command -v gh >/dev/null 2>&1; then
    echo "Creating repository via GitHub CLI..."
    gh repo create "${GITHUB_REPO}" --public --source=. --remote=origin --push=false \
      --description "Multi-branch test repo for WI-440219 patch propagation" 2>/dev/null \
      || gh repo view "${GITHUB_REPO}" >/dev/null 2>&1 \
      || { echo "Note: gh repo create failed; ensure repo exists or set GITHUB_TOKEN." >&2; return 1; }
    return 0
  fi

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "Creating repository via GitHub API..."
    owner="${GITHUB_REPO%%/*}"
    name="${GITHUB_REPO##*/}"
    curl -sf -X POST \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/user/repos" \
      -d "{\"name\":\"${name}\",\"description\":\"Multi-branch test repo for WI-440219 patch propagation\",\"private\":false}" \
      >/dev/null 2>&1 \
      || curl -sf \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPO}" >/dev/null 2>&1 \
      || { echo "Failed to create or access ${GITHUB_REPO}. Set GITHUB_TOKEN or create the repo manually." >&2; return 1; }
    return 0
  fi

  echo "Install 'gh' CLI or set GITHUB_TOKEN to auto-create the repository."
  echo "Or create it manually: https://github.com/new  →  ${GITHUB_REPO##*/}"
  return 1
}

setup_remote() {
  git remote remove origin 2>/dev/null || true
  git remote add origin "${REMOTE_URL}"
  echo "Remote 'origin' → $(git remote get-url origin)"
}

remote_repo_exists() {
  if command -v gh >/dev/null 2>&1; then
    gh repo view "${GITHUB_REPO}" >/dev/null 2>&1
    return $?
  fi

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -sf \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/${GITHUB_REPO}" >/dev/null 2>&1
    return $?
  fi

  # Without gh/token we cannot verify; attempt push and rely on create step.
  return 1
}

ensure_github_repo() {
  if remote_repo_exists; then
    echo "GitHub repository exists: ${GITHUB_REPO}"
    return 0
  fi

  echo "GitHub repository not found: ${GITHUB_REPO}"
  create_github_repo
}

setup_remote
ensure_github_repo

echo ""
echo "Pushing all branches..."
if ! git push -u origin --all; then
  echo "" >&2
  echo "Push failed. Common fixes:" >&2
  echo "  1. Create the repo on GitHub: https://github.com/new?name=kla-complex-test-repo" >&2
  echo "  2. Or install gh and authenticate:" >&2
  echo "       sudo apt install gh && gh auth login" >&2
  echo "  3. Or export a token: export GITHUB_TOKEN=ghp_xxxx" >&2
  echo "  4. Re-run: ./scripts/push_all_branches.sh ./complex-test-repo ${GITHUB_REPO}" >&2
  exit 1
fi

echo ""
echo "Pushing tags (if any)..."
git push origin --tags 2>/dev/null || true

echo ""
echo "Done. View branches at:"
echo "  https://github.com/${GITHUB_REPO}/branches"
echo "  https://github.com/${GITHUB_REPO}/network"
