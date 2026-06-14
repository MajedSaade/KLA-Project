#!/usr/bin/env bash
#
# setup_github_and_push.sh — One-time GitHub auth helper, then push both repos.
#
# Prerequisites (pick one):
#   1. GitHub CLI:  sudo apt install gh && gh auth login
#   2. Personal access token:
#        export GITHUB_TOKEN=ghp_your_token_here
#
# Usage:
#   ./scripts/setup_github_and_push.sh
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITHUB_USER="${GITHUB_USER:-MajedSaade}"
TOOLING_REPO="${GITHUB_USER}/KLA-Project"
TEST_REPO="${GITHUB_USER}/kla-complex-test-repo"

echo "=== KLA Patch Propagation — GitHub Push Setup ==="
echo ""

if ! command -v gh >/dev/null 2>&1 && [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GitHub authentication required. Choose one option:"
  echo ""
  echo "  Option A — GitHub CLI (recommended):"
  echo "    sudo apt install gh"
  echo "    gh auth login"
  echo ""
  echo "  Option B — Personal access token:"
  echo "    export GITHUB_TOKEN=ghp_xxxxxxxx"
  echo ""
  echo "Then re-run: ./scripts/setup_github_and_push.sh"
  exit 1
fi

create_repo_if_needed() {
  local repo="$1"
  local desc="$2"
  if command -v gh >/dev/null 2>&1; then
    gh repo view "${repo}" >/dev/null 2>&1 \
      || gh repo create "${repo}" --public --description "${desc}"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    local name="${repo##*/}"
    curl -sf -X POST \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/user/repos" \
      -d "{\"name\":\"${name}\",\"description\":\"${desc}\",\"private\":false}" \
      >/dev/null 2>&1 \
      || curl -sf -H "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${repo}" >/dev/null
  fi
}

echo ">>> Ensuring GitHub repositories exist..."
create_repo_if_needed "${TOOLING_REPO}" "Patch propagation tooling and CI"
create_repo_if_needed "${TEST_REPO}" "Multi-branch test repo for WI-440219 patch propagation"

echo ""
echo ">>> Pushing tooling repository (${TOOLING_REPO})..."
cd "${ROOT}"
git push -u origin main

echo ""
echo ">>> Regenerating and propagating test repository..."
"${ROOT}/scripts/run_pipeline.sh" "${ROOT}/complex-test-repo"

echo ""
echo ">>> Pushing all 14 branches (${TEST_REPO})..."
"${ROOT}/scripts/push_all_branches.sh" "${ROOT}/complex-test-repo" "${TEST_REPO}"

echo ""
echo "=== Done ==="
echo "Tooling repo : https://github.com/${TOOLING_REPO}"
echo "Test repo    : https://github.com/${TEST_REPO}"
echo "Branch graph : https://github.com/${TEST_REPO}/network"
echo "CI runs      : https://github.com/${TOOLING_REPO}/actions"
