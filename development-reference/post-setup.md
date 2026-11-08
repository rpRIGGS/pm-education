# PM Education — POST Development Server Setup

**Status:** Code committed; NOT yet tested in FiveM. Do not assume production readiness.

## Installation

1. Copy the GitHub resource into your server resources directory (keep folder name `pm-education`).
2. Ensure `oxmysql`, `qb-core`, `ox_lib`, and `qb-target` are started before `pm-education`. This resource uses QBCore, qb-target and ox_lib; it does not require ox_target or ox_inventory.
3. Import **the complete** `sql/pm_education.sql` into the development server database. It creates enrollment, written attempts, practical results, and milestone credential tables.
4. In `config.lua`, configure the POST entries below before testing. **Empty arrays intentionally disable POST interactions**, so the resource can start without made-up map coordinates.
5. Add `ensure pm-education` after the dependencies in `server.cfg`.
6. Use a test citizen and instructor job to verify enrollment, exams, practical assessments, completion, and credentials. Review server/client console errors before using live data.

## REQUIRED POST placeholders

### 1. Admissions NPC

Add to `Config.Institutions.post.admissions`:

```lua
{ model = 'a_m_m_business_01', coords = vector4(X, Y, Z, HEADING), label = 'POST Admissions' }
```

Replace X/Y/Z/HEADING with actual academy coordinates.

### 2. Written-exam NPC

Add to `Config.Institutions.post.examiners`:

```lua
{ model = 'a_m_m_business_01', coords = vector4(X, Y, Z, HEADING),
  label = 'POST Examiner', courses = {'post_basic'} }
```

### 3. Instructor management desk

Add to `Config.Institutions.post.management`:

```lua
{ coords = vector3(X, Y, Z), heading = HEADING, length = 1.5, width = 1.5,
  label = 'POST Instructor Management' }
```

This uses a qb-target box zone, not an NPC or slash command.

### 4. Authorized staff jobs

Replace `staffJobs = {}` with **real jobs and minimum grade levels** from your current `jobs.lua`:

```lua
staffJobs = {
  YOUR_POST_INSTRUCTOR_JOB = { minGrade = 2 }
}
```

**Do not leave the sample job identifier in place.** Server validates both the current job/grade and distance from a configured management desk.

### 5. Written question bank

`server/questions.lua` contains an intentionally empty `EducationQuestions.post.post_basic` list until you approve POST material. A course with no written questions **cannot complete or award accreditation**, even if all practical results pass. Example question shape:

```lua
questions = {
  { question = 'Replace with approved academy question',
    answers = {'Option A', 'Option B', 'Option C'}, correct = 2 }
}
```

`passPercent = 80` is provisional. Course and exam fees are currently 0.

## Already configured

- Institution: `post`, course: `post_basic`.
- Three example instructor practicals: Code 5 stop, pursuit, evasive driving. Adjust the academy curriculum before launch.
- Instructor results: pass/fail/incomplete, notes, authenticated examiner ID, SQL history.
- Written exam results: scored on the server, saved in SQL.
- Progress: students and instructors can inspect requirement completion.
- Milestone credential: `post_basic_accreditation` is issued in SQL only after written and practical requirements pass.
- Student credential lookup from Admissions → My Credentials.
- Server export: `exports['pm-education']:HasCredential(citizenid, 'post_basic_accreditation')` returns a boolean, server-side only.

## NOT implemented / pending integration

- Printed certificate item/image and custom qb-inventory metadata.
- POST credential suspension, revocation and renewal management UI.
- Instructor authority finer than configured job/grade.
- Society account routing for paid university courses; current cash deductions do not deposit into society accounts.
- QB-Phone notifications, PS-MDT integration and final academy curriculum.
- Full enrollment administration (withdrawal, dismissal, reinstatement) and audited corrections.
- Server-side test results and load/security testing.

**Known caution:** Current enrollment and exam fee handling is an early foundation, not a fully transactional banking integration. Test using zero-fee POST before testing paid institutions.

## Testing safeguards and known behavior

- POST has `requireWritten = true`: an empty written question bank blocks accreditation. This is deliberate.
- Cancelling an exam clears its in-memory session, but currently does not refund a charged fee.
- Practical-only courses at other institutions can omit `requireWritten` and `questions`; they still require every configured practical assessment to pass.
- Completion records are milestones, not government license issuance.
- **Security improvement committed:** questions and answer keys now live in `server/questions.lua`, loaded server-side only. Continue testing session security, fee handling, and grading before consequential use.
- **Credential administration pending:** revocation/suspension workflows and audited result corrections are not implemented. Do not use this build for consequential live accreditation decisions.

## Current source-of-truth files

- `config.lua`: institution metadata, POST location/job placeholders, fees, practical requirements.
- `server/questions.lua`: **server-only** written questions and answer keys; do not add this file to shared scripts.
- `server/server.lua`: authenticated enrollment, examination, practical assessment, credential logic.
- `sql/pm_education.sql`: all four database tables.
- `fxmanifest.lua`: includes `@oxmysql/lib/MySQL.lua` before the server scripts.

**Known testing limitation:** Instructor access stays disabled until a real job/grade and management desk are configured. POST enrollment and examinations likewise need real NPC positions. No location has been invented.
