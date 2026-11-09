# Checkpoint 1 — POST gameplay workflow audit

Scope: POST only. SAFR/SAMS remain placeholders. This is a source-level audit, not a FiveM runtime pass.

## Gameplay paths traced
1. Admissions -> server-side proximity and configured course -> enrollment lookup -> approved exam readiness -> payment ledger/debit -> revision pinning -> enrollment -> society credit.
2. Examiner -> configured course allowlist and proximity -> active enrollment -> pinned questions -> fee -> server-held answer key -> score -> attempt record -> completion refresh.
3. Instructor -> job/grade and management proximity -> student enrollment -> pinned practical list -> evaluation -> append-only results -> completion refresh.
4. Student -> owner-only enrollment progress -> practical checklist -> credentials and receipts.
5. Administrator -> separate job/grade and management proximity -> curriculum revisions and credential status audit.

## Fixed during checkpoint
- Optional instructor notes are accepted as empty.
- Enrollment locks are released using source-to-citizen ownership on disconnect.
- Completion practical queries include institution and course scope.
- Instructor practical history is institution-scoped.
- Payment ledger finalization failure is reported as reconciliation required, not successful.
- Expired pending exam sessions no longer block the student permanently.
- Practical evaluation completion refresh returning nil is treated as a failure requiring review.

## Safety behavior retained
- No fabricated academy coordinates, instructor jobs, credentials or examination answers.
- No automatic job, rank or license grants.
- Payment uncertainty blocks repeat charging pending manual reconciliation.
- Enrollment and exam revision pinning retained.
- Credentials are awarded from server-verified requirements only.
- Existing SAFR/SAMS configuration and Sandy Shores University remain out of scope.

## Unverified until checkpoint 4 / staging
- Lua compiler and CI outcomes.
- SQL migrations against real oxmysql.
- qb-banking export behavior and society account existence.
- Resource lifecycle, qb-target NPC and box-zone behavior.
- Full in-game POST student/instructor/admin acceptance tests.

Next: checkpoint 2 — complete and verify user-facing student, instructor and administrator interactions, then checkpoint 3 config, checkpoint 4 static/integration verification and checkpoint 5 installation handoff.
