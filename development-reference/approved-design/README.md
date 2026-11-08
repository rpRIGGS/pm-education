# PM Education — Approved Development Design Reference

**Status:** Planning decisions agreed in conversation, November 2026. This document records intended behavior; it does **not** claim these features are implemented.

**Scope:** Expand the `mundstockGG/qb-university` fork into **PM Education** for PowerMoves RP. Keep the existing jobs inventory in [../README.md](../README.md). This document is the functional reference for later implementation; do not treat examples as a final course catalog.

## 1. Core purpose and boundaries

PM Education is **one shared educational, examination, qualification, and records system** used by independent institutions. It is not synonymous with Sandy Shores University, and is not six separate scripts.

It manages enrollment, course access, written exams, instructor-entered practical evaluation results, prerequisites, fees, educational awards, credentials, status history, and optional printed certificates.

**It does not itself** grant a government license or permit, issue a concealed weapons permit, run a background check, promote/change a QBCore job or rank, appoint an employee to a unit, or perform specialized shooting/driving simulations. Existing licensing, law-enforcement, government, personnel, and practical-test systems retain those authorities.

A passed exam, completed training, or awarded certificate is **evidence of qualification**, not automatic permission to exercise a licensed power or fill a job position. Training can put someone in an eligible applicant/promotion pool; an authorized human or separate system still makes the final decision.

## 2. Three architectural layers

1. **Institutions and locations:** Each institution independently configures campuses/offices, admissions clerks, professors/examiners, management interaction points, courses offered, staff permissions, and financial recipients.
2. **Courses, exams, and qualifications:** Shared enrollment, written testing, practical-result recording, prerequisite checks, attempts, scores, retakes, completions, and renewable/permanent credentials. Exams may be statewide standardized or agency-specific.
3. **SQL records and verification:** One authoritative persistent history for enrollments, attempts, results, awards, status changes, and audit trails. Other scripts and eventually PS-MDT consume these records without duplicating them.

Lua configuration defines institutions, courses, interaction locations, exam settings, fees, notification policies, and award presentation; **SQL**, not a JSON file, is authoritative for player/institution records.

## 3. Institutions, oversight, and jobs

Use **institution** as the generic term, not `agency` or `school`. Examples: Sandy Shores University, POST, SAFR academy, SAMS medical training, agency training divisions, DMV, and government education/licensing offices.

Institutional offerings can serve the existing job groupings: **SADLE**, **SADOJ**, **SAFR**, **SAMS**, **SAGOV**, **SADOT**, and civilian/commercial jobs. Refer to the separate [jobs reference](../README.md) for actual identifiers; do not duplicate the full list here.

POST provides statewide law-enforcement education/accreditation; specialized agencies can add their own requirements. SAFR, SAMS, DOJ, government, transportation, universities, and civilian employers can use the same infrastructure with their own curricula and rules. Additional institutions, jobs, courses, and jurisdictions must be configurable later.

Sandy Shores University is a central civilian/professional campus, **not** the required location for all education. Academy and agency courses may operate entirely at their own headquarters, branches, or training facilities.

## 4. Unlimited configurable locations and interaction types

An institution may have **multiple facilities and multiple points of each type**, all operating on the same institution records with permission checks. For example, POST may have several admissions NPCs, multiple professors, and several instructor-management desks across its main and secondary facilities; BCSO may offer access at headquarters and Paleto.

- **Admissions clerk NPC:** Configurable model/vector4, available programs and courses, enrollment, payment, retakes, and **My Enrollments** lookup.
- **Professor/examiner NPC:** Configurable model/vector4, course(s), written examinations, and classroom or room label. Preserve the original `qb-university` professor/classroom experience.
- **Instructor/institution management point:** Configurable vector location at a desk/office, interacted with through **qb-target**, with no mandatory NPC. Multiple points per institution; configurable authorized courses and staff permissions.
- **Course availability:** Define which courses/exams are offered at which locations and by which instructors. Shared standardized exams need not be duplicated for each branch.
- **Directions:** Enrollment can display and send campus/facility, course code, professor, and room number. Room labels are configurable; an indoor map blip is not required. Do not require fixed class dates for self-paced courses; support future session/deadline rules only where configured.

Use **QBCore**, **qb-target**, custom **qb-inventory**, and **ox_lib** menus/inputs as appropriate. Do not migrate to ox_target or ox_inventory.

## 5. Enrollment and institution management

Enrollment through an admissions NPC creates an SQL enrollment record/reference number linked to the citizen, institution, and program/course. The student may attend or test later; the original enrollment remains accessible via **My Enrollments** and phone confirmations.

Authorized staff use institution management to:
- Search students/enrollments and view their course and requirement progress.
- Enter instructor-assessed practical results (pass/fail/incomplete; optional notes, examiner, date, location, and optional scores).
- Review attempts and results, including auditable corrections.
- Manually enroll where permitted; **withdraw**, **dismiss**, or **reinstate** cadets/students, with permissions and reasons.
- Review whether a student's required written and practical components are complete and whether a milestone credential is eligible.

**Enrollment lifecycle:** enrolled → in progress → completed, withdrawn, or dismissed; reinstatement/re-enrollment handled by explicit authorized action. A student who withdraws or is dismissed is **not deleted**: keep exam attempts, achievements, reasons, staff identity, and timestamps. Previously earned qualifications should not be erased automatically; determine continued validity by policy.

Permissions should distinguish instructor/result-entry privileges from higher administrative rights such as dismissal, reinstatement, corrections, and credential status changes. Staff can only manage authorized institutions/courses; employment alone does not automatically grant universal access.

**Instructor practical results are a records-entry capability, not a new gameplay simulator.** Example: POST instructor conducts Code 5 stop, pursuit, and evasive-driving exercises in roleplay, then records the cadet's results at an academy management desk. Same capability can serve SAFR and SAMS, and is optional for university courses. The approved instructor management UI concept includes enrolled student, evaluation, pass/fail/incomplete, optional notes, and an authenticated submit/save action.

## 6. Exams, prerequisites, and credentials

- Written multiple-choice examinations retain the original university script's test/retake concept, with configurable pass criteria, fees, course association, and prerequisites.
- Distinguish **exam attempt/result**, **completed requirement**, **qualification/certificate**, and **external final authorization**.
- A final credential may require multiple written exams and instructor-entered practical results. Not every requirement produces a physical paper item.
- Support **permanent** awards and **time-limited/renewable** qualifications, including expiry and authorized suspension/revocation where applicable.
- Statewide exams may be shared across institutions/locations; individual agencies may have customized courses or exam variants for their responsibilities.
- Store each credential's owner type appropriately: **citizen**, **business**, or **institution/agency**, as needed. For position/rank prerequisites, record individual qualification without assigning that position or rank.
- Accreditations and significant milestones may produce a final printed certificate; small intermediate requirements generally remain database-only.
- Credential issuance should require verified completion of its defined prerequisites; preserve audit history of issuance and changes.

### Law enforcement / POST example

POST initial coursework and required assessments lead to a **statewide individual law-enforcement accreditation**. Later courses can establish Motor Unit, K9, aviation, protective detail, investigative, or other specialized qualifications. A Sergeant exam can be a prerequisite for promotion, but passing it **does not promote** the officer. Statewide credentials follow the individual; agency-specific training may not transfer automatically.

An agency may also complete an affirmative oath/standards acknowledgment workflow (e.g. constitutional and state standards commitments) to produce a separate **agency accreditation record**, distinct from individual officer accreditation. This creates a documented paper trail; it does not automatically confer statutory authority or replace legal/administrative approval.

### Fire, medical, legal, government, and commercial examples

SAFR academy qualifications, SAMS/medical education (including degree milestones and continuing education), DOJ-related professional courses, government/vending education, mechanic specialties (e.g. paint), and university/vocational courses use the same engine. A restaurant applicant may first earn statewide food-safety training and then present that prerequisite to a county permit authority. **PM Education documents the education; the government issues the actual permit.**

## 7. Separate practical-testing scripts and licensing authority

**Do not recreate an existing shooting-range or driving-test script inside PM Education.** The user has an existing practical shooting qualification resource (exact name/integration to confirm). Document it as an **optional companion integration** in the fork README once identified, **not a hard dependency** preventing PM Education from starting.

- **Weapons permit example:** PM Education records written firearms-safety exam/certificate. Separate range script conducts shooting qualification and produces its own result/receipt. An authorized law-enforcement officer performs background review and uses the existing QB police weapons-license issuance workflow. A government licensing office then issues the physical license through its existing process. PM Education grants none of those final authorizations.
- **Driver license example:** DMV admissions offers regular/commercial written exams through PM Education. A separate driving-test script checks written-pass status and administers road testing. Existing DMV/City Hall licensing issues the actual physical license afterward.
- **Career example:** POST practical assessment results may be entered by authorized instructors, or supplied by specialized scripts if integrated. Passing qualifications never auto-assigns a unit, job, or rank.

Provide a **simple server-side read-only export** for other resources to check a citizen's written-exam result or qualification status (illustrative concept: `HasPassedExam(citizenid, examId)`). Final API names/parameters are not decided. Prefer the export over direct SQL access by other scripts. Later integrations may use authorized write operations for verified external results, but do not assume that functionality is already approved or implemented.

## 8. Printed certificates and custom qb-inventory

SQL is authoritative even if a printed item is lost, destroyed, or never issued. Printed milestone awards are **configurable**, not mandatory for every course.

Use a manageable set of **institution-branded item types and shared PNGs** (e.g. all Sandy Shores University diplomas share an image; POST printed awards share an image; SAFR printed awards share an image). Multiple different credentials can use the same institutional image/item type, distinguished by **item metadata**.

Suggested metadata: certificate ID, recipient/citizen ID, title/qualification ID, issuing institution, issue date, optional expiration date, and verification reference. Actual item names, image assets, and final metadata schema remain to be defined. A dozen or more physical item types is acceptable if useful; avoid a unique PNG for every minor requirement.

## 9. Enrollment fees, retakes, and society banking

Set **fees per course/exam** in config, including `0` for POST/state-sponsored requirements. Retake fees can differ. Funds go to the configured **institution/issuing authority society account** through the existing qb-management/qb-banking setup, rather than all fees going to one universal account.

Sandy Shores University should have its own job/society account; its receipts may serve as an intentional economy sink. Track payer, amount, recipient, enrollment/exam, and available transaction reference in SQL. Never let a failed phone notification undo a successful enrollment/payment.

## 10. QB-Phone notifications and student recall

Include **optional QB-Phone text and email notifications** alongside existing on-screen feedback. Configure channels **per institution and event**, not as a universal message for every tiny accomplishment.

Useful events: enrollment confirmation, major enrollment/status changes (withdrawn, dismissed, reinstated, cancelled), and major final award/accreditation. Individual routine test results can be on-screen only. POST need not send a message for every minor requirement.

Enrollment email should include **institution, enrollment/reference number, course title/code, assigned professor, facility, classroom/room, and enrollment status**, using real configured data. Do not invent class times for self-paced enrollment. Student can revisit the message days later or ask the admissions clerk for **My Enrollments** if the message was deleted.

Email and SMS should be **independently configurable** (screen only, email, SMS, or combinations); use a modular QB-Phone adapter. Phone absence/unavailability must not block enrollment or invalidate records. Actual QB-Phone version/API to confirm before implementation.

## 11. PS-MDT integration roadmap and source of truth

PM Education owns **training/enrollment/credential records**. PS-MDT's six interfaces—SADLE.net, SADOJ.net, SAFR.net, SAMS.net, SAGOV.net, SADOT.net—can later **read** relevant records, with POST having its own training/personnel context under SADLE. Initial integration should be read-only and respect jurisdictional/agency permissions.

PS-MDT retains agency personnel/ranks, cases, internal affairs/discipline, and other oversight records; existing QBCore and government/licensing systems retain job, appointment, license, and permit actions. Do not maintain two conflicting education databases.

If future MDT UI performs education administration, it should call PM Education's authorized server functions instead of directly duplicating enrollment logic. An MDT disciplinary case may prompt an authorized credential suspension workflow, but should not silently mutate the education record.

Plan searchable, auditable SQL records for enrollment status/history, examination attempts/results, instructor evaluations, issued credentials, issuing authority, renewals, expiration, suspension/revocation, and authorized staff actions.

## 12. Implementation guardrails and unresolved details

**Agreed:** institution-based configuration; unlimited branch/interaction locations; admissions NPCs, professor NPCs, management vectors; full enrollment lifecycle; role-restricted instructor evaluation entry; SQL source of truth; exam prerequisites and milestone awards; optional institution-branded inventory certificates; configurable fees/society routing; optional per-event QB-Phone messaging; read-only verification export; eventual MDT read integration; external scripts retain practical tests and licensing authority.

**To confirm before coding:** actual POST/SAFR/SAMS academy coordinates and NPCs, course catalog and exam questions, per-institution permissions/rank thresholds, exact fee amounts, institution job/society definitions, QB-Phone API, custom inventory item names/images, external shooting/driving script names/APIs, credential validity periods, and final SQL/export schema.

This reference documents **approved design**, not a claim of completed implementation. Do not modify root README, script logic, or unrelated projects merely to record these planning decisions.
