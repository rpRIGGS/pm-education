# PM Education — multi-institution rollout

The single PM Education QBCore resource serves multiple institutions with isolated course IDs, enrollments, curriculum revisions, exam attempts, instructor evaluations, and credentials. No separate script per institution is needed.

## Current institution roster

| Institution ID | Status | Initial curriculum | Physical access |
| --- | --- | --- | --- |
| `post` | Configured, provisional | POST Basic Academy: Code 5, pursuit, evasive driving | Unconfigured |
| `safr` | Configured, provisional | Fire & Rescue Foundations: scene safety, fire response, rescue response | Unconfigured |
| `sams` | Configured, provisional | Medical & EMS Foundations: patient assessment, care, handoff | Unconfigured |
| `sandy_university` | Disabled placeholder | Future university offerings | Disabled; inherited demo coordinates are not approved |

SAFR and SAMS course names, credential IDs, practicals and 80% written thresholds are **draft planning examples**, not official or approved standards. Staff must review before publishing. Written questions intentionally remain empty.

## Configuration pattern

For each institution in root `config.lua`:
- `society`: qb-banking account identifier; verify the account before enabling paid courses.
- `staffJobs`: authorized instructor job names and minimum grades.
- `credentialAdminJobs`: independent curriculum and credential administrator jobs/grades.
- `admissions`: qb-target admissions NPC with model, vector4 coordinates and label.
- `examiners`: qb-target written-exam NPC with model, vector4 coordinates and course allowlist.
- `management`: qb-target instructor/administrator box zone with vector3 coordinates.
- `courses`: explicitly offered course keys, fees and requirements.

Empty desks and empty role tables are intentional safe placeholders. They must not silently grant access. `enabled=true` does not spawn any interactions until configured.

## Draft import and publication

1. Developer reviews `development/institutions/{post,safr,sams}.lua`.
2. Run `pm_education_import` from the server console after SQL installation.
3. Import creates reviewable draft revisions, never publishes automatically and never overwrites in-game edits.
4. Authorized institution leadership edits and publishes approved curriculum using its management desk.
5. Students enroll only through a configured admissions interaction; written exams require approved questions.
6. Instructors evaluate practicals; server records credential awards only after all requirements are satisfied.
7. Credentials never automatically grant jobs, ranks, licenses or government permissions.

## Staging validation by institution

Repeat for POST, SAFR and SAMS separately:
1. Confirm no NPCs/zones appear with empty coordinates and no unauthorized instructor access.
2. Configure temporary *real* staging coordinates and jobs; verify admissions and examination interactions.
3. Import a draft; verify it is not published or offered automatically.
4. Approve and publish a test revision; confirm student sees correct course preview.
5. Verify no-charge fail-closed behavior for a course whose written exam has no questions.
6. Supply authorized test questions; enroll, take exam, record each practical, inspect progress and award credential.
7. Verify cross-institution separation, including attempts to access another institution's enrollment or credentials.
8. Verify instructor-only, admin-only, both, neither; test job/grade changes and desk proximity.
9. Confirm revision pinning for existing students when staff publish a new revision.
10. Test payment failure, resource restart, DB failure and audit trails.

**Execution status:** GitHub code is committed; FiveM runtime, GitHub Actions and database integration outcomes have not been verified here.
