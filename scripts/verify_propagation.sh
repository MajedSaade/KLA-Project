#!/usr/bin/env bash
#
# verify_propagation.sh — Assert cross-branch patch propagation outcomes.
#
# Usage:
#   ./scripts/verify_propagation.sh [REPO_DIR]
#

set -euo pipefail

REPO_DIR="${1:-./complex-test-repo}"
WI_ID="${WI_ID:-WI-440219}"
AFFECTED_FILE="${AFFECTED_FILE:-src/payment/transaction_queue.py}"
FIX_MARKER="${FIX_MARKER:-threading.RLock()  # WI-440219: definitive thread-safe fix}"
ENQUEUE_MARKER="${ENQUEUE_MARKER:-def enqueue(self, txn: dict) -> None:}"

# Branches that MUST contain the definitive fix after propagation
EXPECTED_FIXED=(
  bugfix/payment-patch
  feature/payment-gateway
  feature/ledger-audit
  feature/compliance-reporting
)

# Branches that must NOT contain the affected file (fix irrelevant)
EXPECTED_NO_FILE=(
  main
  release/v1.0
  feature/user-auth
  feature/ui-ux
  feature/analytics-pipeline
  feature/notifications
  feature/mobile-api
  feature/database-migration
  feature/admin-dashboard
  infra/kubernetes-config
)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass=0
fail=0

check_pass() {
  echo -e "${GREEN}PASS${NC}  $*"
  pass=$((pass + 1))
}

check_fail() {
  echo -e "${RED}FAIL${NC}  $*" >&2
  fail=$((fail + 1))
}

branch_has_file() {
  git -C "${REPO_DIR}" cat-file -e "$1:${AFFECTED_FILE}" 2>/dev/null
}

branch_content() {
  git -C "${REPO_DIR}" show "$1:${AFFECTED_FILE}" 2>/dev/null
}

echo "Propagation Verification"
echo "======================"
echo "Repository: ${REPO_DIR}"
echo ""

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "Error: ${REPO_DIR} is not a Git repository." >&2
  exit 1
fi

echo "--- Branches that MUST have the fix ---"
for branch in "${EXPECTED_FIXED[@]}"; do
  if ! branch_has_file "${branch}"; then
    check_fail "${branch} — expected file '${AFFECTED_FILE}' missing"
    continue
  fi
  content="$(branch_content "${branch}")"
  if echo "${content}" | grep -Fq "${FIX_MARKER}" \
    && echo "${content}" | grep -Fq "${ENQUEUE_MARKER}"; then
    check_pass "${branch} — definitive fix present"
  else
    check_fail "${branch} — fix marker or enqueue method missing"
  fi
done

echo ""
echo "--- Branches that must NOT have the affected file ---"
for branch in "${EXPECTED_NO_FILE[@]}"; do
  if branch_has_file "${branch}"; then
    check_fail "${branch} — unexpected file '${AFFECTED_FILE}' present"
  else
    check_pass "${branch} — no affected file (correctly skipped)"
  fi
done

echo ""
echo "--- WI noise check (only one definitive fix commit message) ---"
definitive_count="$(
  git -C "${REPO_DIR}" log --all --oneline \
    | grep -F "Apply definitive thread-safe fix" \
    | grep -cF "${WI_ID}" || true
)"
if [[ "${definitive_count}" -ge 4 ]]; then
  check_pass "Definitive fix propagated to multiple branches (${definitive_count} commits)"
else
  check_fail "Expected ≥4 definitive-fix commits across branches, found ${definitive_count}"
fi

wi_total="$(
  git -C "${REPO_DIR}" log --all --oneline --grep="${WI_ID}" | wc -l | tr -d ' '
)"
if [[ "${wi_total}" -ge 8 ]]; then
  check_pass "WI-tagged commit history preserved (${wi_total} total WI commits)"
else
  check_fail "Expected ≥8 WI-tagged commits, found ${wi_total}"
fi

echo ""
echo "Results: ${pass} passed, ${fail} failed"

if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi

exit 0
