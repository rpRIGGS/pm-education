# POST pilot — development-server handoff

**Status:** Source implementation and static contract checks prepared. **NOT** verified in a running FiveM server; do not claim gameplay, SQL, banking or GitHub Actions passed.

**Scope:** POST `post_basic` only. SAFR and SAMS are placeholders and must not be configured as part of this pilot.

## Before installing

1. Back up the development database and the existing `pm-education` resource.
2. Pull the latest `main` of `rpRIGGS/pm-education`; retain folder name `pm-education`.
3. Ensure the development server runs QBCore, `oxmysql`, `ox_lib`, `qb-target`, and `qb-banking`. The custom qb-inventory is compatible but no certificate item is automatically issued.
4. Apply SQL in the order listed in `development-reference/staging-validation.md`. Fresh installs require the base and catalog schemas plus the catalog-attempt, enrollment-revision and exam-revision migrations. Existing databases require review for duplicates and already-applied columns/indexes before applying migrations.
5. In `config.lua` set only POST's real admissions `vector4`, examiner `vector4` with `courses = {'post_basic'}`, and management `vector3`; set approved instructor `staffJobs` and independent administrator `credentialAdminJobs`. Do not fabricate roles or locations.
6. Add approved POST written questions in server-only `server/questions.lua` **or** publish an approved `post_basic` exam through the authorized catalog. Confirm provisional 80% passing score, fees (currently zero), practical labels and credential naming before real use.
7. Verify that the `post` society account exists in qb-banking, then `ensure pm-education` after dependencies.
8. Run `pm_education_post_check` from the server console. Treat any PENDING line as a configuration issue; the legacy question-bank check can be PENDING when an approved published exam substitutes for it. Run `pm_education_catalog_check post` and `pm_education_payment_review post` from the server console as applicable.

## Acceptance tests in FiveM

Use a disposable test citizen and distinct instructor/admin jobs. Keep POST fees at zero for the first end-to-end pass.

| # | Action | Required result |
|---|---|---|
| 1 | Start resource with empty POST desks | No accidental POST NPC or instructor zone; no startup errors |
| 2 | Configure actual POST admissions, examiner and management points | qb-target interactions appear at the configured locations |
| 3 | Attempt admission without approved written questions | Enrollment blocked before charging when `requireWritten=true` |
| 4 | Configure/publish approved exam, enroll student | One enrollment; one receipt; correct pinned revisions |
| 5 | Repeat enrollment / spam enrollment requests | No duplicate enrollment or duplicate charge |
| 6 | Attempt exam outside configured examiner / wrong course | Server rejects the request |
| 7 | Begin and cancel exam; attempt malformed submission | No grading bypass or fabricated pass |
| 8 | Pass written exam | Server saves score, progress updates, no premature accreditation |
| 9 | Non-instructor attempts practical evaluation | Server rejects; no record created |
| 10 | Instructor evaluates Code 5, pursuit, evasive driving at management desk | Append-only results; student sees latest statuses, not private notes |
| 11 | Fail then pass one practical | Latest evaluation determines completion |
| 12 | Finish all required assessments | Enrollment becomes completed; exactly one `post_basic_accreditation` credential |
| 13 | Repeat grading/completion attempts | No duplicate accreditation; completed assessments read-only |
| 14 | Authorized credential admin suspends, restores and revokes test credential | Audit history persists; `HasCredential` respects current status |
| 15 | Non-admin tries credential status change | Server rejects |
| 16 | Restart resource, reconnect and review | Enrollment, practicals, attempts, receipts, credentials and audit persist |
| 17 | Test nonzero fee in isolated staging only | Confirm cash/bank debit, society credit and ledger reconciliation; never blindly retry uncertain credits |
| 18 | Enroll across two published course/exam revisions | Existing enrollment remains pinned to its original revisions |

## Stop conditions

Stop testing and collect logs if any money is debited without a traceable ledger entry, a credential is issued without all POST requirements, unauthorized staff can grade or change credentials, a pinned revision changes unexpectedly, or a migration fails. Do not deploy to the live server until the failing case is corrected and rerun.

## What is not included

- Academy location coordinates, job names/grades, approved POST question content, and final policy decisions.
- Automated employment, police rank, MDT, government license, or qb-inventory certificate grants.
- Verified FiveM runtime, MariaDB migration, GitHub Actions success, qb-banking export behavior, or load/concurrency tests.

## Handoff decision

The source is prepared for the owner to supply POST-specific values and run staging tests. This is **configuration-ready**, not **runtime-verified**. The next gate is to record actual CI, SQL and FiveM test results against the deployed commit.
