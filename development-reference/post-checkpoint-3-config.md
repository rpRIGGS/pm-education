# POST checkpoint 3 — configuration completion gate

**Scope:** POST only. This records the configuration contract; no fabricated academy values were added.

## Runtime source of truth
- `config.lua` -> `Config.Institutions.post` (enabled, society, staffJobs, credentialAdminJobs, admissions, examiners, management, post_basic course).
- `server/questions.lua` -> server-only legacy POST question bank, OR an approved published POST exam in the SQL catalog.
- `server/post_readiness.lua` -> console-only `pm_education_post_check` for deployment configuration diagnostics.
- `server/catalog.lua` and `client/catalog.lua` -> authorized published curriculum and exam management.

## Exact missing user-supplied values
1. POST admissions NPC model and real `vector4` position.
2. POST written examiner NPC model and real `vector4` position; must offer `courses = {'post_basic'}`.
3. POST management `vector3` position and optional heading/box dimensions.
4. Approved instructor job names/minimum grades and independently approved credential administrator job names/minimum grades.
5. Approved POST exam question bank (server-only or published exam) and final pass percentage (currently provisional 80%).
6. Confirm POST society account `post` exists in qb-banking and approve fees (currently zero).

## Completed source checks
- POST placeholders remain empty, not invented.
- POST basic course has written requirement, credential and three instructor practicals.
- Client/server student progress and administrator callbacks are present.
- `server/questions.lua` is loaded server-side only.
- `server/post_readiness.lua` is included in fxmanifest and command is console-only.
- Failed pinned exam curriculum/question lookups clear pending sessions before payment.

## Not yet verified
- GitHub Actions run status: no pull-request-triggered workflow run was returned for the queried commit; this does **not** establish a pass or failure.
- Lua 5.4 compilation and SQL migrations against MariaDB/oxmysql.
- Real qb-target, qb-banking and FiveM execution.

**Next:** checkpoint 4 static/integration verification and fixes; checkpoint 5 final POST development-server handoff. SAFR and SAMS placeholders remain untouched.
