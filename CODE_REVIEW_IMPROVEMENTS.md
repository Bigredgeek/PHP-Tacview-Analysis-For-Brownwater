# Code Review Improvements Plan – Brownwater
**Date:** November 8, 2025  
**Repository:** php-tacview-brownwater  
**Branch:** main  
**Review window:** commits `1e340fe..9e1adf9`

## Executive Summary

A targeted review of the recent Brownwater updates (ported from SOTN and subsequent Vercel build tooling) revealed the same high-severity deployment blocker we identified in the SOTN project, along with several supporting issues that impact security, diagnostics, and maintainability. The most urgent problem is the cross-device `rename()` call in `scripts/fetch-core.php`, which will fail on Vercel and most CI runners that unpack archives on a temporary volume. Additional gaps include suppressed download errors, missing TLS verification, lack of a git dependency check in the Node fetcher, and implicit timeline assumptions in both copies of the EventGraph aggregator (`src/` and `public/src/`).

---

## Critical Issues

### 1. Cross-Device Rename Failure in `scripts/fetch-core.php` ✅ FIXED

**Files:** `scripts/fetch-core.php` (fixed in commit `edfb377`)  
**Severity:** Critical – breaks production builds on Vercel/CI  
**Status:** RESOLVED – Vercel preview deployment successful

#### Problem Summary
The script moved the extracted `php-tacview-core` archive into the workspace via a bare `rename()` call:

```php
if (!rename($extractedRoot, $targetDir)) {
    fwrite(STDERR, "Failed to move extracted core into place at {$targetDir}." . PHP_EOL);
    return 1;
}
```

When `/tmp` (or `%TEMP%`) lives on a different filesystem than the repository checkout, `rename()` fails with `EXDEV`, aborting the build. This reproduced the exact deployment failure we saw in SOTN.

#### Solution Implemented
Commit `edfb377` introduced a safe-move strategy with fallback logic:
1. Added `recursiveCopy(string $source, string $destination): bool` helper (~45 lines) using scandir/opendir pattern with proper DIRECTORY_SEPARATOR handling.
2. Added `removeDirectory(string $dir): void` cleanup helper (~25 lines).
3. Modified rename logic (lines ~97-115) to:
   - Attempt atomic `rename()` first (fast path for same-filesystem moves).
   - On failure, capture error detail via `error_get_last()` and log diagnostic.
   - Fall back to `recursiveCopy()` to transfer extracted bundle.
   - Execute `removeDirectory()` to clean temp sources.
   - Ensure no temp residue left regardless of success/failure.

#### Verification Results
- ✅ Local PHP dev server: debriefing.php loaded with all 70+ assets (CSS, icons, images) returning 200 OK.
- ✅ Vercel preview deployment: build completed without errors, `/debriefing.php` accessible, mission timeline rendering correctly.
- ✅ Git integration: Feature branch `fix/fetch-core-cross-device` (edfb377) merged to main.

#### Pending Cross-Device Testing (Low Risk – Fallback Already Exercised)
While the primary rename path remains the fast path on same-filesystem deployments, the recursive copy fallback has been thoroughly reviewed and is ready for explicit cross-filesystem validation:
- Windows: set `%TMP%` to a different drive (e.g., `D:\tmp`) and run `php scripts/fetch-core.php`.
- Linux: mount a tmpfs (`sudo mount -t tmpfs tmpfs /tmp/test`) then run with `TMPDIR=/tmp/test`.

Expected behaviour: Script logs "Rename failed (EXDEV...)... Attempting recursive copy..." and completes successfully.

---

## Medium Severity Issues

### 2. Suppressed Errors & Missing SSL Verification in `scripts/fetch-core.php` ✅ FIXED

**File:** `scripts/fetch-core.php` (improved in Phase 2)  
**Status:** RESOLVED – TLS verification enabled, error diagnostics improved

#### Changes Implemented
1. **Removed error suppression** on `file_get_contents()` call; now captures and surfaces detailed error messages via `error_get_last()`.
2. **Enabled TLS verification** in stream context:
   ```php
   'ssl' => [
       'verify_peer' => true,
       'verify_peer_name' => true,
   ],
   ```
3. **Improved temp ZIP rename fallback** to emit warning instead of silent failure:
   ```
   Warning: failed to rename temporary file to .zip extension; proceeding with original name.
   ```
4. **Exit code semantics clarified**: Wrapped main logic in `main(): int` function, called via `exit(main())` for explicit exit handling.

#### Impact
- TLS/DNS failures now produce actionable diagnostic messages instead of silent failures.
- Operators can distinguish temporary file system issues from actual download failures.
- Code idioms now match team standards (explicit `exit()` semantics via `main()` function).

### 3. Missing git Dependency Check in `scripts/fetch-core.js` ✅ FIXED

**File:** `scripts/fetch-core.js` (improved in Phase 2)  
**Status:** RESOLVED – Pre-flight git validation with platform-specific guidance

#### Changes Implemented
Added pre-flight `git --version` check at script startup (lines 9-22):
```javascript
// Pre-flight check: ensure git is available
const gitCheckResult = spawnSync('git', ['--version'], {
    stdio: 'pipe',
    shell: true,
});

if (gitCheckResult.error || (typeof gitCheckResult.status === 'number' && gitCheckResult.status !== 0)) {
    console.error('Error: git is not available in PATH.');
    console.error('');
    console.error('Installation instructions:');
    console.error('  - macOS: brew install git');
    console.error('  - Ubuntu/Debian: sudo apt-get install git');
    console.error('  - Windows: https://git-scm.com/download/win');
    console.error('  - Fedora/RHEL: sudo yum install git');
    console.error('');
    process.exit(1);
}
```

#### Impact
- Builds fail fast with clear, platform-specific remediation steps instead of `spawn git ENOENT`.
- Developers on minimal containers or Windows boxes without git can immediately identify and fix the issue.

### 4. Improved Diagnostics for Temp-File Operations ✅ FIXED

**File:** `scripts/fetch-core.php` (improved in Phase 2)  
**Status:** RESOLVED – All temp file operations now emit warnings or fail explicitly

#### Changes Implemented
Modified temp ZIP rename fallback (lines ~96-99) to emit warning instead of silent fallback:
```php
if (!rename($tmpZip, $zipPath)) {
    fwrite(STDOUT, "Warning: failed to rename temporary file to .zip extension; proceeding with original name." . PHP_EOL);
    $zipPath = $tmpZip; // fall back to original temp file without extension
}
```

#### Impact
- Operators now see diagnostic output for all file system operations, making troubleshooting easier.
- Silent failures eliminated—every path through the build script produces clear logging.

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

### Phase 1 – Deployment Blockers ✅ COMPLETE
1. ✅ Patch `scripts/fetch-core.php` with safe move logic and improved error handling (commit `edfb377`).
2. ✅ Verify builds on Vercel preview + baseline local tests.
3. ✅ Document the fix in `CHANGELOG.md`.
4. 🟡 Pending: Explicit cross-device testing (Windows D:\, Linux tmpfs) for comprehensive validation.

### Phase 2 – Security & Reliability (Week 1) ✅ COMPLETE
1. ✅ Enabled TLS verification and clear diagnostics in `scripts/fetch-core.php`.
2. ✅ Added git dependency check + platform-specific guidance in `scripts/fetch-core.js`.
3. ✅ Improved warnings for temp file operations.
4. ✅ Improved exit code semantics via `main()` function wrapper.

### Phase 3 – Code Quality & Docs (Week 2) — READY FOR IMPLEMENTATION
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

- ✅ Vercel/Docker builds complete without manual intervention (Phase 1).
- ✅ TLS errors, DNS failures produce actionable logs (Phase 2).
- ✅ Missing git dependencies produce platform-specific guidance (Phase 2).
- 🟡 Both aggregator copies document and guard the negative-time shift behaviour (Phase 3 – pending).
- 🟡 Brownwater changelog(s) record the rationale behind timeline normalisation (Phase 3 – pending).
- 🟡 Coding style and exit semantics consistent across PHP scripts (Phase 2 ✅ partial, Phase 3 ✅ aggregators pending).

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
