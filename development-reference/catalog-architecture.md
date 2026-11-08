# PM Education — versioned curriculum catalog

## Verified repository inventory (code review only; no FiveM runtime test)
- `config.lua`: institution IDs, jobs, management desks, course defaults and fees. POST permissions and desk coordinates remain unconfigured; Sandy Shores University is disabled.
- `server/questions.lua`: legacy server-only question bank; POST remains empty.
- `development/institutions/post.lua` and `sandy_university.lua`: server-only development templates. No unapproved exam questions seeded.
- `sql/pm_education.sql`: enrollment, exam attempts, practical evaluations, credentials, payments and audit records.
- `sql/pm_education_catalog.sql`: course/exam/credential revision catalog and audit.
- `sql/pm_education_catalog_attempts_migration.sql`: nullable attempt-to-exam-revision link.
- `server/catalog.lua`: administrator-scoped list/read/create/save/publish/retire/history callbacks.
- `server/import.lua`: console-only development-template import. Changed templates create new review drafts; existing content is not overwritten.
- `client/catalog.lua`: ox_lib draft editor for questions, answer choices, course titles/scores, credential titles, and publishing.
- `client/main.lua`: qb-target management desk entry point.
- `server/server.lua`: existing enrollment/payment/credential engine, now selecting published exam questions and saving the selected revision ID.

## Setup
Apply `sql/pm_education.sql`, then `sql/pm_education_catalog.sql`, then `sql/pm_education_catalog_attempts_migration.sql` **once** on an existing database (inspect existing schema before rerunning ALTER). Start `pm-education` after QBCore, oxmysql, ox_lib, qb-target, qb-banking. Run `pm_education_import` in the server console to stage development templates as drafts. Publication is always manual.

## Version behavior
Published content is not editable in place. Staff create replacement drafts, edit, retire the old published revision, and publish the new revision. In-flight exam sessions retain their captured questions and answer key. New attempts store their catalog revision ID; historical attempts have NULL and remain valid. Credential status changes are separate from test revisions. Development imports do not grant licenses, ranks, jobs or permits.

## Critical outstanding work
1. FiveM/oxmysql runtime testing, including actual SQL migrations and management desk permissions.
2. Strengthen database concurrency controls and audit transaction boundaries for draft edits/imports; publication now uses a transaction for retirement, activation and audit.
3. Expand runtime integration beyond published course labels/passing scores and credential labels: practical requirements, enrollment policies, prerequisites and richer credential rules remain config-driven.
4. Conflict-safe import previews and a round-trip conversion from exported JSON into reviewable development Lua templates. A console-only JSON export is now available.
5. Better administrator UX (richer credential requirements, unsaved-change warnings) and full end-to-end tests.
6. Replace provisional POST curriculum only after approval; never invent job grades, coordinates, or policy questions.

**Do not mistake committed code for production-tested functionality.** The earlier setup guide contains historical development notes that have been superseded; use this inventory and the actual source files for the current catalog state.

## Import fingerprint behavior
The console importer stores a source fingerprint for each development-authored revision. Re-running an unchanged template does not create another draft even if an administrator subsequently edits that draft. Changed source templates create separate revisions for review. Hashes are non-cryptographic change identifiers; they are not authenticity proofs. All imports still require explicit publication.

## Published course and credential integration
For existing configured courses only, newly published course catalog records override course label and pass percentage in the server's course lookup; fee settings, practical requirements and credential identifiers remain controlled by `config.lua`. Newly awarded credentials use the label from the matching published credential catalog revision if available. Existing credentials are never relabeled. Publication retires the previous published revision in the same SQL transaction as activating its replacement and writing the publication audit. This does not yet guarantee race-free publication by concurrent administrators, and requires live concurrency testing.

## Additional transaction hardening
Draft save, explicit retirement, and publication now pair content changes with audit inserts in SQL transactions. These transaction calls still require concurrency and affected-row verification in a running FiveM/oxmysql environment; transaction success alone does not prove the targeted row changed. Course publication is limited to course IDs present in the institution configuration, preventing drafts for unoffered courses from appearing operational.

## Console export
Use `pm_education_export post` (or another configured institution ID) in the **server console**. This writes `export_<institution>.json` at the resource root, including all revisions and exam answer keys for development review. Do not put exported JSON in a client-served resource, public repository, or web-accessible folder. Export is a snapshot, not an automatic GitHub push or re-import; review before adapting content back into development templates. The resource directory must be writable by the server process.

## Integrity checks and authoring safeguards
Run `pm_education_catalog_check post` from the server console after migrations and after bulk curriculum imports. The read-only audit checks JSON payload shape, published exam questions and answer keys, course registry linkage, duplicate active revisions, missing development import fingerprints, duplicate imports, and orphaned historical attempt revision links. It prints findings to the server console and never modifies records. The exam editor supports up to eight answer choices. The exam and completion paths fail closed when published curriculum cannot be loaded, rather than mistaking a database outage for a course with no written requirement.

Catalog draft allocation retries unique-key collisions up to three times. This is not a substitute for transactionally pairing creation and audit, nor for multi-server publication locking. Do not interpret a clean audit as proof that gameplay tests passed.

## Live course discovery
The admissions and examination menus now use a server callback that reads published course titles and passing percentages. Only course IDs already configured for that institution are returned. Server-side fee values remain authoritative and examiner menus still restrict courses to the examiner's configured offer list. The callback validates a player's proximity to an admissions or examiner point, and fails closed if the catalog query errors. Existing student enrollment lists also use the published course title when available. This does not yet make newly invented course IDs enrollable without adding an approved configuration entry and an examination location.

## Editable course curricula
Published course revisions now supply the server with written-examination requirements, practical evaluation IDs/titles and linked credential metadata in addition to title and passing percentage. The in-game draft editor supports adding, renaming, removing and reordering practical evaluations; IDs remain stable once created. Instructors receive sanitized published evaluation requirements instead of static client configuration. Fees, access policy, physical interaction points and the set of offered course IDs remain configured server-side.

**Important outstanding decision:** Existing enrollments currently evaluate against the latest published course revision. Before production use, add an enrollment-level curriculum revision snapshot so publishing changed practical requirements cannot silently alter an enrolled student's obligations. Do not publish requirement changes to a live class until this is implemented and tested.

## Enrollment curriculum revision pinning
Apply `sql/pm_education_enrollment_revision_migration.sql` after the catalog schema. New enrollments store `curriculum_revision_id` when a published course exists. Progress, completion, and practical-result authorization resolve this original revision even if it has since been retired. Existing records keep NULL and retain legacy/config-based behavior; **do not automatically backfill** them with the newest revision.

**Known blockers before production:** The current server script contains repeated registration/handler sections that must be consolidated before live testing. Exam questions are still selected from the current published exam rather than an enrollment-pinned exam revision; the exam and course revision relationship needs explicit handling. Instructor course outlines must be made enrollment-specific. Existing legacy NULL enrollments still need a defined long-term snapshot policy.

## Handler consolidation and exam pinning follow-up
The server handler registrations have been consolidated into one set after a duplicated/corrupted source-file issue was found. New enrollment rows now also pin `exam_revision_id` when a published exam exists; apply `sql/pm_education_exam_revision_migration.sql` after the curriculum migration. Examination delivery and progress calculations use that revision, including retired exam records. Instructor course outlines now resolve the selected enrollment's curriculum and require instructor authorization.

Legacy enrollments with NULL revision pointers still use the configured/latest curriculum or exam; a historical snapshot cannot be reconstructed reliably. Existing courses with no published exam likewise continue to use the legacy question bank until a published exam is available. Neither case is represented as a historical revision guarantee. Run Lua syntax checks and FiveM integration tests before deployment.
