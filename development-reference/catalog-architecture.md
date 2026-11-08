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
4. Export of in-game content back to reviewable development files, and conflict-safe import previews.
5. Better administrator UX (richer credential requirements, unsaved-change warnings) and full end-to-end tests.
6. Replace provisional POST curriculum only after approval; never invent job grades, coordinates, or policy questions.

**Do not mistake committed code for production-tested functionality.** The earlier setup guide contains historical development notes that have been superseded; use this inventory and the actual source files for the current catalog state.

## Import fingerprint behavior
The console importer stores a source fingerprint for each development-authored revision. Re-running an unchanged template does not create another draft even if an administrator subsequently edits that draft. Changed source templates create separate revisions for review. Hashes are non-cryptographic change identifiers; they are not authenticity proofs. All imports still require explicit publication.

## Published course and credential integration
For existing configured courses only, newly published course catalog records override course label and pass percentage in the server's course lookup; fee settings, practical requirements and credential identifiers remain controlled by `config.lua`. Newly awarded credentials use the label from the matching published credential catalog revision if available. Existing credentials are never relabeled. Publication retires the previous published revision in the same SQL transaction as activating its replacement and writing the publication audit. This does not yet guarantee race-free publication by concurrent administrators, and requires live concurrency testing.
