# PM Education — Current implementation inventory

**Reviewed:** 2026-11-11  
**Repository:** `rpRIGGS/pm-education`, current `main` source inspected.  
**Purpose:** A single, code-grounded baseline before further implementation. This document is a snapshot, not a claim of runtime readiness.

## Status definitions

- **Implemented (source):** Corresponding code exists; runtime behavior is not necessarily verified.
- **Configured (placeholder):** Schema/course structure exists, but operational details are intentionally unset.
- **Unverified:** No successful, recorded end-to-end verification has been established by this inventory.
- **Planned:** Approved direction without a demonstrated complete implementation.

## Source inventory

| Area | Current finding | Evidence |
|---|---|---|
| Runtime/framework | Implemented (source): QBCore, ox_lib, qb-target, oxmysql, qb-banking dependencies | `fxmanifest.lua` |
| Institution/course definitions | Implemented (source): centralized authoritative institution config | `config.lua` |
| Admissions and enrollment | Implemented (source): student enrollment, payment ledger, lock/ownership and failure handling | `server/server.lua` |
| Written examinations | Implemented (source): examiner access, server-only answer keys, attempt persistence, paid-session retry and cancellation | `server/server.lua`, `server/questions.lua`, `client/main.lua` |
| Instructor practical grading | Implemented (source): role/proximity checks, pass/fail/incomplete, notes, append-only results and completion refresh | `server/server.lua` |
| Student and instructor records | Implemented (source): enrollment, progress, practical history and credential callbacks; ox_lib/qb-target UI | `server/server.lua`, `client/main.lua` |
| Credential status and audit | Implemented (source): authorized suspension/restoration/revocation, history and server-side status checks | `server/server.lua` |
| Catalog editing and revisions | Implemented (source): catalog and import/export/discovery modules; revision pinning in enrollment and exam flows | `server/catalog.lua`, `server/import.lua`, `server/export.lua`, `server/course_discovery.lua` |
| Database | SQL schemas and migration scripts exist; execution against deployment database unverified | `sql/` |
| Automated verification | GitHub Actions Lua and SQL/static checks configured; passing run not established in this inventory | `.github/workflows/lua-check.yml` |
| Deployment diagnostics | Read-only POST readiness and catalog/payment checks exist; do not prove gameplay | `server/post_readiness.lua`, `server/catalog_check.lua` |
| FiveM end-to-end validation | **Unverified**; no completed development-server acceptance run recorded | `development-reference/post-development-server-handoff.md` |

## Institution readiness

| Institution | Source configuration | Remaining setup |
|---|---|---|
| POST (`post`) | Enabled, `post_basic` course, provisional 80% written threshold, Code 5 / pursuit / evasive practicals, `post_basic_accreditation` | Admissions/examiner/management vectors; instructor/admin jobs and grades; approved questions or published exam; final policy and tests |
| SAFR (`safr`) | Enabled but interaction arrays empty; provisional foundations course and three practical requirements | Approved curriculum, exam, vectors, staff/admin permissions, institution tests |
| SAMS (`sams`) | Enabled but interaction arrays empty; provisional foundations course and three practical requirements | Approved curriculum, exam, vectors, staff/admin permissions, institution tests |
| Sandy Shores University (`sandy_university`) | Disabled; inherited demonstration courses and locations are **not** approved SSU setup | Real SSU locations, curriculum, staff permissions and tests |

**Important:** `enabled = true` with empty interaction arrays does not mean an academy is operational. POST/SAFR/SAMS placeholders must not be filled with invented vectors, job rules or examination material.

## Open implementation and verification work

1. Audit complete enrollment → examination → practical evaluation → progress → accreditation → credential administration lifecycles, including failure, disconnect, retry, permissions and duplicate-action paths. Recent commits improve these paths but do not establish end-to-end correctness.
2. Run and record actual GitHub Actions checks, Lua compilation and SQL schema/migration verification against the intended database version; resolve failures rather than inferring success from static checks existing.
3. Reconcile source and documentation on the exact available admin functions and external integrations. In particular, withdrawal/dismissal/reinstatement, QB-Phone messaging, printed qb-inventory certificates, external practical-resource adapters and PS-MDT integration are **not verified complete** here.
4. Verify deployment configuration and POST end-to-end acceptance tests in a development server when actual academy-specific settings are available. Keep these placeholders from blocking unrelated source work.
5. Extend and verify approved SAFR/SAMS and university workflows using the shared engine, without inventing curricula or locations.

## Operational constraints and decisions

- Keep QBCore, qb-target and custom qb-inventory compatibility. Do not migrate to Qbox, ox_target or ox_inventory.
- Education records qualifications; it must not automatically grant government licenses, police jobs/ranks, promotions or MDT authority.
- `server/questions.lua` remains server-only; never expose answer keys to clients.
- Approved POST exam content may be supplied by the published catalog instead of the legacy empty question list.
- Instructor and credential-administrator permissions are independent and must be configured explicitly.
- Existing `development-reference/post-setup.md` includes historical stage notes and superseded statements (for example cash-only fees, missing credential status UI, missing society routing). Treat its **current configuration authority** section and this inventory as current; do not rely on historical notes for implementation status.
- `development-reference/post-development-server-handoff.md` is an acceptance checklist, **not evidence of tests passed**.
- Preserve the existing approved design and jobs references. This inventory reconciles status; it does not change scope.

## Next development gate

Finish code/SQL/integration verification and document actual results before marking POST source complete or installation-ready. Missing real-world vectors, jobs and approved questions are deployment inputs, not reasons to stop independent development.
