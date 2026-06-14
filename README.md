# KLA Patch Propagation Test Harness

Stress-test environment for automated **cross-branch patch propagation** using work item `[WI-440219]`.

## Quick start

```bash
# Full pipeline: generate repo → propagate fix → verify
./scripts/run_pipeline.sh

# Or step by step:
./generate_complex_repo.sh ./complex-test-repo
./scripts/propagate_patch.sh ./complex-test-repo
./scripts/verify_propagation.sh ./complex-test-repo
```

## Repository layout

| Path | Purpose |
|------|---------|
| `generate_complex_repo.sh` | Builds 14-branch enterprise Git history |
| `scripts/propagate_patch.sh` | Finds the definitive fix and cherry-picks it |
| `scripts/verify_propagation.sh` | Asserts expected branch outcomes |
| `scripts/run_pipeline.sh` | End-to-end local pipeline |
| `scripts/push_all_branches.sh` | Push all branches to GitHub |

## Propagation target

- **Work item:** `[WI-440219]`
- **Source branch:** `bugfix/payment-patch`
- **Definitive commit message:** `Apply definitive thread-safe fix for payment engine [WI-440219]`
- **Affected file:** `src/payment/transaction_queue.py`

The propagator intentionally **ignores** the other 7 WI-tagged commits and only cherry-picks the definitive fix.

## Expected outcomes

| Branch | Expected result |
|--------|-----------------|
| `bugfix/payment-patch` | Already has fix (source) |
| `feature/payment-gateway` | Fix applied |
| `feature/ledger-audit` | Fix applied |
| `feature/compliance-reporting` | Fix applied |
| All other branches | Skipped (file not present) |

## Push to GitHub

```bash
# After running the pipeline:
./scripts/push_all_branches.sh ./complex-test-repo YOUR_USER/kla-complex-test-repo
```

Requires one of:

- [GitHub CLI](https://cli.github.com/) (`gh auth login`)
- `GITHUB_TOKEN` environment variable with `repo` scope

View the branch graph at `https://github.com/YOUR_USER/kla-complex-test-repo/network`.

## CI

GitHub Actions workflow `.github/workflows/patch-propagation.yml` runs on every push/PR:

1. Generates a fresh `complex-test-repo`
2. Runs propagation
3. Verifies outcomes
4. Uploads propagation logs as artifacts
