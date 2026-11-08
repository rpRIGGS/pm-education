# PM Education

**PM Education** is a planned expansion of [Mundstock's qb-university](https://github.com/mundstockGG/qb-university) for the **PowerMoves RP** QBCore FiveM server. The goal is a shared education, examination, and qualification system for universities, public-safety academies, government training offices, and civilian professions.

> **Development status:** This repository is a fork under development. The original university-style professor, enrollment, written examination, and certificate functionality forms the starting point. The broader features described below are **planned**, not a claim that they are already implemented.

## What we're building

- **Independent institutions:** Sandy Shores University, POST, fire/rescue and medical academies, agency training divisions, DMV education, government offices, and vocational programs using one shared system.
- **Configurable locations:** Multiple admissions NPCs, professor/examiner NPCs, and staff management interaction points at any number of facilities for each institution, with course and staff permissions.
- **Enrollment and administration:** Course registration, fees, retakes, student course lookup, instructor results, progress, withdrawal, dismissal, reinstatement, and auditable administration.
- **Written and instructor-assessed training:** Configurable questions, passing requirements, prerequisite courses, and authorized instructor entry of practical roleplay evaluations. External shooting and driving resources continue to conduct their own practical tests.
- **Qualifications and accreditation:** Statewide or institution-specific examinations; permanent and renewable certifications; degrees, academy graduation, POST accreditation, specialized unit qualifications, and promotional-exam results.
- **Persistent records:** SQL-based enrollment, exam, credential, renewal, and status histories, with a simple planned server-side verification export for other resources.
- **Optional printed awards:** Institution-branded diplomas and certificates with custom qb-inventory metadata; routine test results need no physical item.
- **Payments and communication:** Configurable fees routed to institution society accounts through existing banking, plus configurable QB-Phone email/SMS and on-screen enrollment and milestone notifications.
- **Future PS-MDT integration:** Authorized viewing of education and qualification history through the relevant oversight interface, without maintaining a second education database.

## Education versus licensing

**PM Education records education and qualifications; it does not grant government licenses, permits, employment, unit assignments, or promotions.** Those decisions remain with the authorized in-game systems and personnel.

Examples of the intended workflows:

- **Concealed weapons permit:** A citizen passes a firearms-safety written examination through PM Education. A **separate shooting-range script** handles practical qualification. Law enforcement conducts the background check and authorizes the weapons license using its existing workflow; a licensing office issues the physical license.
- **Driver's license / CDL:** A DMV clerk offers written examinations through PM Education. A **separate driving-test resource** can verify the written pass before administering a road test. The appropriate licensing authority issues the actual license.
- **POST / career progression:** Cadets complete required written and instructor-assessed training to earn individual POST accreditation. Motor Unit, K9, aviation, and Sergeant-related training can be recorded as additional qualifications. Passing a Sergeant examination **does not automatically promote** an officer.
- **Business and professional permits:** A restaurant owner may complete food-safety education before applying to a county or city for a permit. Mechanic specialties, medical qualifications, and other professional prerequisites can be documented the same way.

Practical-test resources are **optional companion integrations**, not hard dependencies for PM Education as a whole. Their exact resource names and interfaces will be documented when confirmed.

## Technical direction

**Framework:** QBCore. Preserve **qb-target** interactions and compatibility with the server's customized **qb-inventory**; use **ox_lib** for menus and inputs. Planned integrations include SQL persistence, existing **qb-banking/qb-management** society accounts, and optional **QB-Phone** notifications. Do not substitute ox_target or ox_inventory.

The current upstream resource is named `qb-university`; installation details and resource naming will be revised as PM Education implementation progresses. This README is a project overview, **not** a completed installation or configuration guide.

## Development references

- [Approved development design](development-reference/approved-design/README.md) — agreed features, enrollment lifecycle, instructor management, qualifications, external licensing boundaries, notifications, and future MDT integration.
- [Jobs reference](development-reference/README.md) — existing PowerMoves RP jobs grouped by oversight area and civilian/commercial education opportunities.

These references describe the **planned implementation** and distinguish agreed design from configuration details still to be finalized.

## Original project and license

PM Education is forked from **[mundstockGG/qb-university](https://github.com/mundstockGG/qb-university)**, originally by **Mundstock**. The original project provides professor NPCs, subject enrollment, learning materials, written exams, configurable fees, and certificate awards.

This fork retains the original project's **MIT License**. See [LICENSE](LICENSE) for the full license and original copyright notice, which must remain included in copies or substantial portions of the software.
