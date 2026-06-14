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
  if git remote get-url origin >/dev/null 2>&1; then
    echo "Remote 'origin' already configured: $(git remote get-url origin)"
  else
    create_github_repo || true
    if git ls-remote "${SSH_REMOTE}" >/dev/null 2>&1; then
      git remote add origin "${SSH_REMOTE}" 2>/dev/null || git remote set-url origin "${SSH_REMOTE}"
    else
      git remote add origin "${REMOTE_URL}" 2>/dev/null || git remote set-url origin "${REMOTE_URL}"
    fi
    echo "Remote 'origin' → $(git remote get-url origin)"
  fi
}

setup_remote

echo ""
echo "Pushing all branches..."
git push -u origin --all

echo ""
echo "Pushing tags (if any)..."
git push origin --tags 2>/dev/null || true

echo ""
echo "Done. View branches at:"
echo "  https://github.com/${GITHUB_REPO}/branches"
echo "  https://github.com/${GITHUB_REPO}/network"
