# PM Education — deployment and verification gate

This checklist is for a staging FiveM server with QBCore, qb-banking, qb-target,
ox_lib, oxmysql and the custom QBCore-compatible qb-inventory. Do not deploy
migration files without a database backup.

## Database migration order

1. Install base `sql/pm_education.sql`.
2. Install `sql/pm_education_catalog.sql`.
3. Install `sql/pm_education_catalog_attempts_migration.sql`.
4. Install `sql/pm_education_enrollment_revision_migration.sql`.
5. Install `sql/pm_education_exam_revision_migration.sql`.
6. For installations with an existing catalog schema, run the diagnostic query in
   `sql/pm_education_catalog_published_uniqueness_migration.sql`; resolve
   duplicate published records before applying the ALTER TABLE. **Do not run
   this ALTER on a fresh schema already containing `published_slot`.**

## Preflight checks

- GitHub Actions Lua 5.4 compile check is green for the commit deployed.
- All expected database tables, columns and indexes exist.
- Resource loads without Lua or SQL errors.
- `pm_education_catalog_check <institutionId>` reports no errors.
- Confirm published catalog has no duplicate active revisions.
- Confirm institution staff jobs, grade rules, management desks, admissions
  points, examiner points and society account are actually configured.

## Enrollment revision regression

1. Publish course A revision 1 and exam A revision 1; enroll student 1.
2. Publish course A revision 2 with a different practical requirement;
   publish exam A revision 2 with different questions.
3. Confirm student 1 still sees and is assessed against revision 1.
4. Enroll student 2; confirm revision 2 applies.
5. Retire revision 1. Student 1 must retain their assigned requirements.
6. Attempt to submit a practical requirement that belongs only to revision 2
   for student 1. Server must reject it.
7. Complete each student's assigned requirements; confirm a single credential
   and completed enrollment status.
8. Simulate a failed credential insert in staging. Enrollment must not be
   marked completed if the credential transaction fails.
9. Attempt rapid duplicate exam requests and duplicate completion events.
   Verify no double charges or duplicate credentials.
10. Test old NULL revision enrollments separately; they are legacy and
    **not** historically pinned.

## Permissions and security

- Nonstaff cannot read exam answer keys through catalog callbacks.
- Instructor access fails outside configured management desks.
- Invalid institution IDs, malformed course IDs, missing credentials and
  invalid requirement IDs are rejected without a server crash.
- A client cannot supply another player's citizen ID to read private records.
- Student-facing exam questions never include the correct-answer index.
- Generated export files with answer keys remain server-side and private.

## Limits

CI validates Lua parsing, not FiveM natives, MySQL transactions, game-side
permissions, NPC interactions or economic side effects. These require staging
tests with actual resources and database.

## Additional written-exam and catalog race regressions

- For an enrolled course with `requireWritten=false`, confirm progress ignores
  the legacy exam bank and the exam desk refuses to charge an exam fee.
- For `requireWritten=true` without any available questions, completion must
  remain blocked and no exam fee may be charged.
- For a pinned exam revision, a passing attempt against a different revision
  must not satisfy the written requirement.
- Attempt simultaneous publish/publish and publish/retire actions on the same
  catalog key. Confirm one published revision at most and correct audit records.
- Force an authoring audit insert failure. Draft creation must not report
  success or retry into multiple draft revisions.
- Force the catalog integrity SQL query to fail. The audit must report failure,
  not a misleading zero-error result.

## Historical course metadata

Newly published course revisions materialize their written-exam policy,
practical requirements and credential ID/label into the published payload.
Changing `config.lua` later must not rewrite those published requirements.
The audit warns about older published course revisions without these fields;
review those individually rather than overwriting historical records.

The published credential label is now taken from the student's enrolled course
revision rather than the newest credential-catalog label.

## Authoring transaction and credential consistency

- Force an in-game draft audit insert failure: the draft insert must roll
  back, and a subsequent successful retry must create one audited revision.
- Force a development template import audit insert failure: the imported draft
  must roll back; no unaudited catalog row may remain.
- Confirm completion uses the credential label from the student's enrolled
  curriculum even if a later credential revision changes its display label.
- Confirm catalog audit reports credentials without a matching enrollment
  and duplicated enrollment/credential awards.
