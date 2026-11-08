# Versioned institutional content — implementation notes

## Current implementation
- `sql/pm_education_catalog.sql` creates revisioned course/exam/credential payload storage and an audit table.
- `development/institutions/*.lua` are authoring templates. They are **not automatically imported**, and they do not replace the currently configured courses or server-side questions.
- `server/catalog.lua` provides institution-scoped server callbacks to list and read revisions and create new drafts. They require the institution to be enabled, the authorized `credentialAdminJobs` job/grade, and proximity to an actual configured management desk. POST deliberately has no approved administrator job or desk yet, so its authoring access remains locked.
- Draft creation does **not** publish or activate tests. The current exam runtime continues using the existing server question bank.
- Import reconciliation, draft editing, publishing, immutable snapshot binding, audit writes, export, and ox_lib editing menus are **next implementation tasks**. Do not present the editor as production-ready.

## Content lifecycle contract
1. Development-authored records have stable institution/type/key identifiers.
2. First import creates drafts; subsequent imports compare source content and propose new drafts rather than overwriting live edits.
3. An authorized institution administrator reviews, edits and explicitly publishes a revision.
4. New attempts use the newly published revision; in-progress attempts retain their question/answer snapshot.
5. Historical passing attempts and credentials remain valid under their original revision unless separately suspended, revoked or expired by authorized policy action.
6. Published records must never be edited in place. All modifications are new revisions, with actor and timestamp audit entries.
7. Exports produce portable development source files for review and GitHub commits; no in-game process directly edits resource Lua files.

## Before live testing
Apply both SQL files. Confirm the real job/grade and management-desk coordinates for each institution. Test with an unauthorized job, a lower grade, and another institution's leadership. Never seed unapproved POST questions or silently activate demonstration university courses.
