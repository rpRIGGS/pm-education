# PM Education

**PM Education** is the PowerMoves RP QBCore shared education, academy and accreditation resource, forked from [Mundstock's qb-university](https://github.com/mundstockGG/qb-university).

**Current status (2026-11-11): substantial source implementation, NOT verified development-server ready.** See the [current implementation inventory](development-reference/current-implementation-inventory.md) for the code-grounded feature matrix, institution-by-institution readiness and remaining work. The [POST acceptance checklist](development-reference/post-development-server-handoff.md) is a testing plan, not a record of passing tests.

## Implemented in source

- Shared configurable institution/course engine with QBCore, qb-target, ox_lib, oxmysql and qb-banking.
- Admissions/enrollment, cash/bank payment ledger and society-payment handling, server-graded written examinations and persisted attempts.
- Instructor practical assessment records, student/instructor progress and accreditation completion.
- Authorized credential status changes with audit history and server-side credential verification.
- Catalog management, import/export/discovery modules, published course/exam revision support and SQL schemas/migrations.
- Client interaction menus and console-side readiness/reconciliation checks.
- Automated Lua/static/SQL checks defined in GitHub Actions; a passing run is **not established by this documentation**.

**Implemented in source does not mean integration-tested.** Do not deploy for consequential accreditation or real-money transactions without completing verification.

## Institution configuration

- **POST:** `post_basic`, provisional 80% written pass threshold, Code 5 traffic stop / pursuit / evasive driving practicals, `post_basic_accreditation`. Real interaction vectors, instructor/admin job rules and approved exam content remain unset.
- **SAFR:** provisional fire/rescue foundations course and practicals; academy interaction points, staff roles and approved content remain unset.
- **SAMS:** provisional medical/EMS foundations course and practicals; academy interaction points, staff roles and approved content remain unset.
- **Sandy Shores University:** disabled; inherited demonstration courses and coordinates are not an approved SSU deployment.

The authoritative runtime settings are `config.lua` and server-only `server/questions.lua`; draft files in `development/institutions/` are reference templates. Empty interaction arrays intentionally prevent unconfigured academy interactions.

## Not established as complete

Development-server acceptance, verified GitHub Actions and SQL migration results, final POST/SAFR/SAMS policy and examination content, QB-Phone messaging, printed qb-inventory certificates, external practical-resource adapters and PS-MDT integration. Additional administration workflows such as withdrawal, dismissal and reinstatement require code-level verification before claiming completion.

## Current documentation

- [Implementation inventory and open verification gates](development-reference/current-implementation-inventory.md)
- [POST development-server handoff and acceptance tests](development-reference/post-development-server-handoff.md)
- [POST configuration guide](development-reference/post-setup.md) — includes historical implementation-stage notes; consult the inventory for current status.
- [Approved development design](development-reference/approved-design/README.md)
- [Existing jobs by oversight area](development-reference/README.md)

## Education versus licensing

**PM Education records education and qualifications; it does not grant government licenses, permits, employment, unit assignments, or promotions.** Those decisions remain with the authorized in-game systems and personnel.

Examples of the intended workflows:

- **Concealed weapons permit:** A citizen passes a firearms-safety written examination through PM Education. A **separate shooting-range script** handles practical qualification. Law enforcement conducts the background check and authorizes the weapons license using its existing workflow; a licensing office issues the physical license.
- **Driver's license / CDL:** A DMV clerk offers written examinations through PM Education. A **separate driving-test resource** can verify the written pass before administering a road test. The appropriate licensing authority issues the actual license.
- **POST / career progression:** Cadets complete required written and instructor-assessed training to earn individual POST accreditation. Motor Unit, K9, aviation, and Sergeant-related training can be recorded as additional qualifications. Passing a Sergeant examination **does not automatically promote** an officer.
- **Business and professional permits:** A restaurant owner may complete food-safety education before applying to a county or city for a permit. Mechanic specialties, medical qualifications, and other professional prerequisites can be documented the same way.

Practical-test resources are **optional companion integrations**, not hard dependencies for PM Education as a whole. Their exact resource names and interfaces will be documented when confirmed.

## Original project and license

PM Education is forked from **[mundstockGG/qb-university](https://github.com/mundstockGG/qb-university)**, originally by **Mundstock**. The original project provides professor NPCs, subject enrollment, learning materials, written exams, configurable fees, and certificate awards.

This fork retains the original project's **MIT License**. See [LICENSE](LICENSE) for the full license and original copyright notice, which must remain included in copies or substantial portions of the software.
