# PM Education — frontend integration and deployment inventory

Status: repository implementation reviewed; **not validated on a running FiveM server**.

## Configuration ownership
- `config.lua` at the resource root is the only loaded runtime configuration.
- Removed unused `shared/config.lua` from the original qb-university fork.
- `development/institutions/*.lua` are developer curriculum templates, imported as reviewable drafts; they do not create physical interaction points.
- `server/questions.lua` contains legacy server-only question data; published exam catalog revisions supersede it for new enrollments.

## Student interaction chain
| Player interaction | Client | Server | Deployment prerequisite |
| --- | --- | --- | --- |
| qb-target admissions NPC | `showAdmissions` | `availableCourses`, `enroll` | admissions model + vector4 |
| Enrollment payment | `choosePaymentMethod` | `paymentStart`, `paymentComplete` | permitted method, qb-banking society |
| My Enrollments | `showEnrollments` | `myEnrollments`, `myCourseProgress` | enrolled student |
| My Credentials | `showMyCredentials` | `myCredentials` | valid student session |
| Payment Receipts | `showPaymentReceipts` | `myPayments` | valid student session |
| qb-target examiner NPC | `showExaminer`, `openExam` | `requestExam`, `submitExam`, `cancelExam` | examiner model, vector4, offered courses, approved questions |

## Instructor and administration chain
| Interaction | Client | Server | Deployment prerequisite |
| --- | --- | --- | --- |
| qb-target management box zone | `openInstructorManagement` | `instructorStudents` | management vector3 + instructor job/grade |
| Student assessment | `openInstructorStudent` | `instructorRecordPractical` | authorized staff, active enrollment, approved requirement |
| Curriculum editor | `OpenPMEducationCatalog` | `catalogList`, `catalogGet`, `catalogCreateDraft`, `catalogSaveDraft`, `catalogPublish`, `catalogRetire` | management desk + credential-admin job/grade |
| Credential decisions | `manageStudentCredentials` | credential administration callbacks | credential-admin permission and authorized location |

## POST: configuration still required
- Academy admissions NPC coordinates and model.
- Examiner NPC coordinates and offered POST courses.
- Management desk coordinates, heading and zone dimensions.
- Actual POST instructor and credential-administrator jobs/grades.
- Approved POST written questions, exam pass threshold, credential and practical curriculum.
- Verify `post` qb-banking society account before enabling paid fees.

Do not populate unknown values with fictional coordinates or staff job names.
Sandy Shores University remains disabled until its real site and roles are approved.

## Staging test sequence
1. Install schema and migrations; confirm resource starts without Lua errors.
2. With POST desks empty, verify no unexpected target interactions appear.
3. Configure real POST coordinates/jobs and confirm qb-target interactions appear only at the intended desks.
4. Student: admission, enroll, fee receipt, enrollment history, exam cancel/retry/submit, progress, credential.
5. Instructor: authorized vs unauthorized job/grade and distance, practical pass/fail/incomplete, completion.
6. Administrator: draft edit, publish, retire, new enrollment revision pinning, old enrollment stability.
7. Failure cases: unavailable catalog, failed debit, uncertain society credit, refund reconciliation, resource restart during exam.
8. Confirm no automatic job, rank or license changes from a credential award.

### Known limitations
- Current frontend is ox_lib context menus/input dialogs, **not** a bespoke full-screen NUI.
- POST is not playable until site coordinates, jobs and written material are supplied.
- GitHub Actions and in-server tests have not been confirmed passing.
- Instructor-only staff should not see the curriculum editor; credential administrators still require server authorization.
- New course IDs created in the editor are not automatically offered: the corresponding runtime course must be configured and authorized before publication.
- Do not treat existing older notes about payment integration as current implementation without comparing the runtime.

## Frontend audit follow-up (November 2026)
- Instructor roster and student enrollment menus now resolve the **assigned curriculum revision** rather than a newly published course label.
- Instructor-only jobs do not receive the credential-status or curriculum-editor actions in their menus. Server-side authorization remains mandatory.
- Student payment, credential, and instructor practical-history database failures must show error feedback, not empty-state messages.
- A course with `requireWritten=false` displays "Not required" rather than "Question bank not configured".
- Final authorization and data-consistency verification still requires a live QBCore/ox_lib/qb-target staging environment.

## Credential administration role separation
- `staffJobs` authorizes instructor practical assessments and instructor student records.
- `credentialAdminJobs` independently authorizes curriculum and credential administration.
- Both roles require proximity to a configured `management` desk. An administrator is **not** automatically an instructor.
- An administrator-only user sees a management menu for curriculum and credential administration; an instructor-only user sees assessments, but not credential status controls.
- Test four combinations in FiveM: instructor only, admin only, both, neither. Also test leaving the desk, changing grade/job, and disabled institutions. Client visibility is convenience only; the server must deny unauthorized requests.

## Student gameplay flow implemented with placeholders
1. Student approaches the configured admissions NPC and chooses a course.
2. Course preview shows fees, written-exam policy, passing threshold and ordered practicals.
3. Enrollment checks the approved exam bank and payment ledger before recording the student.
4. At a configured examiner NPC, an enrolled student may take the assigned written exam.
5. Authorized instructors record Code 5 stop, pursuit and evasive-driving outcomes.
6. Student opens My Enrollments -> progress to view the latest status of each practical.
7. Once required exam and practicals pass, the server issues the configured SQL credential.
8. Student sees the awarded credential; this does not automatically change their job, grade or license.

**Placeholder policy:** no invented POST coordinates, staff jobs, or exam answer keys.
The workflow is coded but still requires server execution and test results.

## POST-only completion checkpoint (November 2026)
Development focus is POST exclusively. SAFR and SAMS remain provisional placeholders; do not expand them until POST pilot work is wrapped up.

- Student admissions course preview, enrollment, written exam, instructor practical results, progress refresh, credential review, curriculum editing and credential administration are implemented.
- Instructor and credential administrator permissions are separate, enforced at management desks.
- Practical checklist queries are scoped to enrollment, institution and course; progress summary remains available if detailed lookup fails.
- Examiner menus exclude courses that do not require written exams.
- Management zone cleanup only targets zones that were actually registered.
- GitHub CI checks POST identifiers, practical names, empty desk placeholders and matching client/server callbacks.
- **Read-only console check:** run `pm_education_post_check` to list configured/missing POST desks, role rules and course offering. This does not validate the database, question approval or gameplay.
- **Still unverified:** GitHub Actions execution, SQL installation/migrations, staging interactions, qb-target placement, qb-banking society account and payment tests, approved written questions, instructor evaluations and credential issuance in live FiveM.

Do not claim the POST pilot is live-tested or deployable solely because the static checklist passes.
