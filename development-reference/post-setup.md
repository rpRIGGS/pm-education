# PM Education — POST configuration and staging setup

**Status (2026-11-11):** POST source workflows exist, but end-to-end FiveM, SQL and banking acceptance have **not** been recorded as passing. This document supersedes earlier implementation-stage notes that incorrectly described completed features as missing or cash-only.

For authoritative implementation status see [current implementation inventory](current-implementation-inventory.md). For the 18-step staging test plan see [POST development-server handoff](post-development-server-handoff.md). **Neither document is evidence of a passed test.**

## Current configuration authority

- `config.lua`: live institution/course settings, staff permissions, admission/exam NPCs and instructor management points.
- `server/questions.lua`: server-only legacy question bank; a published approved catalog exam can substitute.
- `server/post_readiness.lua`: console-only, read-only configuration diagnostics.
- `fxmanifest.lua`: actual dependency and resource entrypoints.
- `sql/`: base/catalog schemas and applicable revision migrations. Follow [staging validation](staging-validation.md) for the intended database state.

## Required POST inputs — intentionally not fabricated

| Setting | Required input |
|---|---|
| `Config.Institutions.post.admissions` | Approved NPC model, real academy `vector4`, label |
| `Config.Institutions.post.examiners` | Approved NPC model, real `vector4`, `courses = {'post_basic'}` |
| `Config.Institutions.post.management` | Real instructor/administrator desk `vector3` and qb-target zone dimensions |
| `Config.Institutions.post.staffJobs` | Approved instructor job names and minimum grades |
| `Config.Institutions.post.credentialAdminJobs` | Independently approved credential administrator job names and grades |
| POST written examination | Approved `server/questions.lua` entries **or** published approved catalog exam |
| `post_basic` course | Confirm provisional 80% threshold, zero fees, three practical requirements and credential label |
| `post` society | Existing, accessible qb-banking society account |

Example shapes (replace **all** placeholders with actual approved values):

```lua
admissions = {
  { model = 'a_m_m_business_01', coords = vector4(X, Y, Z, HEADING), label = 'POST Admissions' }
},
examiners = {
  { model = 'a_m_m_business_01', coords = vector4(X, Y, Z, HEADING),
    label = 'POST Examiner', courses = {'post_basic'} }
},
management = {
  { coords = vector3(X, Y, Z), heading = HEADING, length = 1.5, width = 1.5,
    label = 'POST Instructor Management' }
},
staffJobs = { YOUR_APPROVED_INSTRUCTOR_JOB = { minGrade = 2 } },
credentialAdminJobs = { YOUR_APPROVED_ADMIN_JOB = { minGrade = 5 } }
```

The example grades are placeholders, **not** approved policy. Instructor and credential administrator roles are separately checked by the server. Empty location arrays prevent accidental world interactions; they are not a blocker for independent source development.

## Development-server procedure

1. Back up the development database and resource; use the latest committed `rpRIGGS/pm-education` in folder `pm-education`.
2. Ensure `qb-core`, `oxmysql`, `ox_lib`, `qb-target` and `qb-banking` are started. Preserve compatibility with the custom qb-inventory; do not install ox_inventory or ox_target as substitutes.
3. Apply the applicable SQL schemas/migrations following [staging validation](staging-validation.md); do not blindly reapply migrations to an existing database.
4. Enter approved POST-only configuration values and verify the `post` society account. Leave SAFR/SAMS and university placeholders unchanged.
5. Start `pm-education` after dependencies. From the server console run `pm_education_post_check`, `pm_education_catalog_check post` and `pm_education_payment_review post` as applicable.
6. Execute the [POST acceptance tests](post-development-server-handoff.md) using disposable test citizens, instructors and administrators; begin with zero fees. Record actual results and failures against the tested commit.

## Present behavior and boundaries

- Server-only answer keys; written grading and attempts persist to SQL.
- Practical pass/fail/incomplete entries are instructor-authorized and tracked; passing every requirement gates accreditation.
- Credential administrators can suspend, restore a suspended credential or revoke with an audit reason. Revoked credentials are terminal in the present workflow.
- Cash/bank fees and qb-banking society routing are implemented in source, with a ledger and reconciliation paths. This is **not** a claim of tested financial correctness.
- No automatic police job, promotion, government license, MDT authority or physical qb-inventory certificate issuance.
- QB-Phone messaging and external shooting/driving resource integrations are not verified as complete.
- The original university demonstration NPC coordinates are not approved Sandy Shores University locations; that institution stays disabled.

**Next gate:** Record successful source, SQL and runtime verification. Do not treat the existence of code, console checks or GitHub Actions definitions as proof of passing tests.
