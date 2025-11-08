# Code Review Improvements Plan – Brownwater
**Date:** November 8, 2025  
**Repository:** php-tacview-brownwater  
**Branch:** main  
**Review window:** commits `1e340fe..9e1adf9`

## Executive Summary

A targeted review of the recent Brownwater updates (ported from SOTN and subsequent Vercel build tooling) revealed the same high-severity deployment blocker we identified in the SOTN project, along with several supporting issues that impact security, diagnostics, and maintainability. The most urgent problem is the cross-device `rename()` call in `scripts/fetch-core.php`, which will fail on Vercel and most CI runners that unpack archives on a temporary volume. Additional gaps include suppressed download errors, missing TLS verification, lack of a git dependency check in the Node fetcher, and implicit timeline assumptions in both copies of the EventGraph aggregator (`src/` and `public/src/`).

---

## Critical Issues

### 1. Cross-Device Rename Failure in `scripts/fetch-core.php` ⚠️ BLOCKER

**Files:** `scripts/fetch-core.php` (introduced in `1e340fe`)  
**Severity:** Critical – breaks production builds on Vercel/CI

The script moves the extracted `php-tacview-core` archive into the workspace via:

```php
if (!rename($extractedRoot, $targetDir)) {
    fwrite(STDERR, "Failed to move extracted core into place at {$targetDir}." . PHP_EOL);
    return 1;
}
```

When `/tmp` (or `%TEMP%`) lives on a different filesystem than the repository checkout, `rename()` fails with `EXDEV`, aborting the build. This reproduces the exact deployment failure we saw in SOTN.

**Action:** Implement the same safe-move strategy: attempt the rename, fall back to a recursive copy + delete when `rename()` fails, and surface clear diagnostics. Reuse the `recursiveCopy()` helper outlined in the SOTN plan.

**Acceptance tests:**
- Windows: set `%TMP%` to a different drive (e.g., `D:\tmp`) and run `php scripts/fetch-core.php`.
- Linux: mount a tmpfs (`sudo mount -t tmpfs tmpfs /tmp/test`) then run with `TMPDIR=/tmp/test`.
- Vercel preview deployment and Docker multi-stage build should both succeed and leave no temp residue.

---

## Medium Severity Issues

### 2. Suppressed Errors & Missing SSL Verification in `scripts/fetch-core.php`

**File:** `scripts/fetch-core.php`  
**Problems:**
- `@file_get_contents()` hides TLS/DNS/HTTP failures, making debugging impossible.
- Stream context omits TLS verification settings, weakening supply-chain safety.
- No checksum validation for the downloaded archive.

**Action:** Mirror the SOTN remediation—remove the error suppression, capture `error_get_last()` output, enable `verify_peer` / `verify_peer_name`, and (optionally) accept a `TACVIEW_CORE_ARCHIVE_SHA256` env var for checksum enforcement.

### 3. Missing git Dependency Check in `scripts/fetch-core.js`

**File:** `scripts/fetch-core.js`  
The Node fetcher assumes `git` exists. On minimal containers or Windows dev boxes without git in PATH, the build fails with `spawn git ENOENT` and no guidance.

**Action:** Add a pre-flight git check (e.g., `execSync('git --version')`) with installer instructions and an optional manual clone fallback message. Consider leaving the cloned `.git` directory in place for traceability and ignoring it via `.gitignore`.

### 4. Silent Temp-File Rename Fallback

**File:** `scripts/fetch-core.php`  
If renaming the temporary ZIP to add the `.zip` suffix fails, the script silently proceeds with the extensionless path:

```php
if (!rename($tmpZip, $zipPath)) {
    $zipPath = $tmpZip; // silent fallback
}
```

**Action:** Either emit a warning (so operators know the first rename failed) or exit with an explicit error. Matching the SOTN fix keeps behaviour consistent across repos.

### 5. Timeline Normalisation Clarity in Both Aggregator Copies

**Files:**
- `src/EventGraph/EventGraphAggregator.php`
- `public/src/EventGraph/EventGraphAggregator.php`

The `applyStartTimeConsensus()` method now shifts events forward when mission times dip negative, but the code relies on implicit understanding that `$this->events` is non-empty. The same optional clarity fix from SOTN—explicit empty checks and inline comments explaining the negative-time scenario—should be applied to *both* copies so the public bundle stays in sync with the source bundle.

**Action:**
1. Add the explicit empty-array guard to `getMinimumEventMissionTime()`.
2. Document the “why” both in code comments and in the Brownwater `CHANGELOG.md` (and `public/CHANGELOG.md`, since that bundle mirrors the aggregator).

### 6. Non-Idiomatic Exit Codes in `scripts/fetch-core.php`

The script uses bare `return` statements at top level (`return 0;`, `return 1;`). While PHP treats these as exit codes, readers unfamiliar with the pattern may misinterpret them.

**Action:** Switch to `exit()` calls or wrap the script logic in a `main()` function that returns an int, mirroring the style update suggested for SOTN.

---

## Documentation Gaps

### 7. Changelog Context for Mission-Time Shift

Neither `CHANGELOG.md` nor `public/CHANGELOG.md` currently documents the negative mission-time fix that landed with the EventGraph port. Future maintainers have no record of the rationale.

**Action:** Add a “Fixed – 2025-11-05” bullet describing the negative-time scenario (misaligned MissionTime headers across Tacview exports) and the normalisation strategy.

---

## Implementation Plan

### Phase 1 – Deployment Blockers (Immediate)
1. Patch `scripts/fetch-core.php` with safe move logic and improved error handling.
2. Verify builds on Vercel preview + cross-filesystem local tests.
3. Document the fix in `CHANGELOG.md`.

### Phase 2 – Security & Reliability (Week 1)
1. Enable TLS verification and clear diagnostics in `scripts/fetch-core.php`.
2. Add git dependency check + messaging in `scripts/fetch-core.js`; decide whether to retain the cloned `.git/` directory and update `.gitignore` accordingly.
3. Improve warnings for the temp ZIP rename fallback.

### Phase 3 – Code Quality & Docs (Week 2)
1. Update both EventGraph aggregator copies with explicit guards and explanatory comments.
2. Clarify changelog entries for the mission-time normalisation.
3. Swap `return` for `exit()` (or `main()` wrapper) in `scripts/fetch-core.php`.

### Phase 4 – Future Enhancements (Backlog)
1. Add checksum verification for the core archive (`TACVIEW_CORE_ARCHIVE_SHA256`).
2. Evaluate consolidating PHP/Node fetch logic to a single maintained code path.
3. Consider end-to-end integration tests that exercise both the Node and PHP fetchers.

---

## Testing Checklist

- `php scripts/fetch-core.php` (same filesystem) – baseline success.
- Windows cross-drive execution (set `%TMP%` or `%TEMP%`).
- Linux tmpfs cross-device execution (`TMPDIR=/tmp/test`).
- Vercel preview build (ensure `php-tacview-core/` exists post-build).
- Docker multi-stage build using the scripted fetcher.
- Missing git scenario: run `npm run build` in an environment without git and confirm the new error message guides installation.
- SSL failure scenario: point `TACVIEW_CORE_ARCHIVE_URL` at a host with an invalid cert and confirm the script fails loudly.
- Regression check: `npm run build` should still succeed on a fully provisioned dev box and skip redundant downloads when `php-tacview-core/` already exists.

---

## Success Criteria

- ✅ Vercel/Docker builds complete without manual intervention.
- ✅ TLS errors, DNS failures, and missing git dependencies produce actionable logs.
- ✅ Both aggregator copies document and guard the negative-time shift behaviour.
- ✅ Brownwater changelog(s) record the rationale behind timeline normalisation.
- ✅ Coding style and exit semantics in the PHP fetcher match team conventions.

---

## Open Questions

1. Should we keep the `.git` directory inside `php-tacview-core/` for traceability, or continue pruning it after clone?
2. Is checksum verification required for compliance/security reviews, or can we defer to GitHub TLS protection?
3. Do we want to unify the fetch logic across projects by migrating fully to the Node implementation (with PHP retained only as a fallback)?
4. Can we share the improvements (recursive copy helper, TLS enforcement) via a shared script between SOTN and Brownwater to reduce duplication?

---

## Next Steps for Implementers

- Start with the safe-move fix and enhanced diagnostics in `scripts/fetch-core.php`; these unblock deployments and make subsequent testing reliable.
- Mirror the same improvements across SOTN after verification to keep behaviour consistent.
- Follow the testing checklist above, capturing logs for Vercel and cross-volume scenarios to confirm the fix.
- Update the Brownwater changelog(s) once the code changes land, noting both the deployment fix and the mission-time documentation.
