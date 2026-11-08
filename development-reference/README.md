# PM Education — Development Reference

> Planning reference only. This document inventories existing QBCore job identifiers and groups potential education, training, examination, and certification use cases. It does **not** approve courses, mandate certifications, change job ranks, or authorize implementation.

## Source of truth

- Source repository: [rpRIGGS/PowerMoves-PSMDT](https://github.com/rpRIGGS/PowerMoves-PSMDT)
- Source file: [planning-reference/jobs.lua](https://github.com/rpRIGGS/PowerMoves-PSMDT/blob/main/planning-reference/jobs.lua)
- Snapshot reviewed: `main`, Git blob SHA `321517b40e7e00a5562d2b49a21422bbcf8dbdb3`
- The job list is **not** copied into PM Education as a runtime configuration. Recheck the current PS-MDT reference when implementing integration, since identifiers, job status, and agency relationships may change.

The six oversight interfaces are SADLE.net, SADOJ.net, SAFR.net, SAMS.net, SAGOV.net, and SADOT.net. The groupings below represent proposed education/certification domains, **not** a claim that every listed business is directly employed by, or administratively controlled by, that oversight agency.

## 1. SADLE — Law enforcement oversight (10)

Potential use: POST academy, agency onboarding, specialty qualifications, recurring training, promotional examinations.

| Job ID | Job label |
| --- | --- |
| `post` | Peace Officer Standards and Training |
| `sadle` | San Andreas Division of Law Enforcement |
| `lspd` | Los Santos Police Department |
| `lscso` | Los Santos County Sheriff's Office |
| `bcso` | Blaine County Sheriff's Office |
| `sahp` | San Andreas Highway Patrol |
| `sasp` | San Andreas State Parks |
| `saspa` | San Andreas State Prison Authority |
| `lspe` | Los Santos Parking Enforcement |
| `police` | Law Enforcement (generic job) |

POST is a candidate provider of common training to multiple agencies; individual departments may also administer local or promotional exams.

## 2. SADOJ — Justice and courts (1)

Potential use: court procedures, clerk education, legal practice and judicial training.

| Job ID | Job label |
| --- | --- |
| `sadoj` | San Andreas Department of Justice |

`judge` and `lawyer` appear inside a commented-out block in the source and are **not active entries in this inventory**.

## 3. SAFR — Fire and rescue oversight (4)

Potential use: fire academy, rescue and incident-command qualifications, hazardous-materials courses, promotional examinations.

| Job ID | Job label |
| --- | --- |
| `safr` | San Andreas Fire Rescue |
| `lsfd` | Los Santos Fire Department |
| `lscfd` | Los Santos County Fire Department |
| `bcfd` | Blaine County Fire Department |

## 4. SAMS — Medical oversight (5)

Potential use: EMS and clinical education, professional qualifications, continuing education, supervisory exams.

| Job ID | Job label |
| --- | --- |
| `sams` | San Andreas Medical Services |
| `pillboxmed` | Pillbox Hill Medical Center |
| `sandymed` | Sandy Shores Medical Center |
| `paletomed` | The Bay Care Center |
| `parsonsmed` | Parsons Rehabilitation Center |

## 5. SAGOV — Government oversight (5)

Potential use: government administration, licensing, tax assessment, zoning, public-service and job-center training.

| Job ID | Job label |
| --- | --- |
| `sagov` | State of San Andreas |
| `bcgov` | Blaine County Government |
| `lscgov` | Los Santos County Government |
| `lsgov` | City of Los Santos Government |
| `lsjc` | Los Santos Job Center |

## 6. SADOT — Transportation oversight / related vocational qualifications (13)

Potential use: commercial driving, transit, transportation licensing, air traffic control, fleet maintenance, inspection, and equipment training.

| Job ID | Job label |
| --- | --- |
| `sadot` | San Andreas Department of Transportation |
| `safleet` | San Andreas State Fleet Maintenance |
| `bcfleet` | Blaine County Fleet Maintenance |
| `lscofleet` | Los Santos County Fleet Maintenance |
| `lscityfleet` | City of Los Santos Fleet Maintenance |
| `lst` | Los Santos Transit Authority |
| `bus` | Bus |
| `trucker` | Trucker |
| `tow` | Towing |
| `taxi` | Taxi |
| `atc` | LSIA Air Traffic Control |
| `atcss` | Sandy Shores Air Traffic Control |
| `jetsam` | Jetsam Logistics |

This is a qualification/education grouping; private operators do not thereby become SADOT employees.

## 7. Civilian and commercial education (27)

Potential use: Sandy Shores University, professional development, vocational courses, business operations, and industry-specific training. These are not assigned to a new oversight agency.

| Sector | Job ID | Job label |
| --- | --- | --- |
| Automotive sales/service | `cardealer` | Premium Deluxe Motorsport |
| Automotive sales/service | `paradise` | Motorcycle Paradise |
| Automotive sales/service | `larrys` | Larrys RV Sales |
| Automotive sales/service | `benefactor` | Benefactor-Gallivanter |
| Automotive sales/service | `mechanic` | LS Customs |
| Automotive sales/service | `mechanic2` | LS Customs |
| Automotive sales/service | `mechanic3` | LS Customs-LSIA |
| Automotive sales/service | `beeker` | Beekers Garage |
| Automotive sales/service | `bennys` | Benny's Original Motor Works |
| Real estate/finance | `realestate` | Dynasty8 Realty |
| Real estate/finance | `arcadius` | Arcadius Investments Group |
| Real estate/finance | `thediamond` | The Diamond Corporation |
| Real estate/finance | `prix` | Prix Luxury Real Estate |
| Hospitality/food service | `burgershot` | Burger Shot |
| Hospitality/food service | `hookiesmp` | Horneys Mirror Park |
| Hospitality/food service | `horneyspb` | Horneys Paleto Bay |
| Hospitality/food service | `horneysss` | Horneys Sandy Shores |
| Hospitality/food service | `horneyssls` | Horneys South Los Santos |
| Hospitality/food service | `hookies` | Hookies |
| Hospitality/food service | `hotdog` | Hotdog |
| Agriculture/production | `marlowe` | Marlowe Vineyard |
| Agriculture/production | `vineyard` | Vineyard |
| Retail/technology | `fruit` | iFruit Store LS |
| Other businesses | `murkoff` | Murkoff Corporation |
| Civilian services | `reporter` | Reporter |
| Civilian services | `garbage` | Garbage |
| Civilian services | `unemployed` | Civilian |

**Note:** `unemployed` (Civilian) is included to make this a complete source-file inventory. It was omitted from the earlier 27-job civilian/commercial breakdown, which instead counted only 26 civilian/commercial job IDs. The full source inventory is therefore **65 unique job identifiers**; the earlier breakdown counted 64 entries despite reporting 65. Civilians may take general courses without a job assignment.

## Counts

| Group | Unique job IDs |
| --- | ---: |
| SADLE | 10 |
| SADOJ | 1 |
| SAFR | 4 |
| SAMS | 5 |
| SAGOV | 5 |
| SADOT | 13 |
| Civilian / commercial (including `unemployed`) | 27 |
| **Total** | **65** |

## Source-file caveats

- `fib` (Federal Investigation Bureau) is commented out/disabled. The source notes SADLE as the sole statewide LEO oversight agency.
- `judge` and `lawyer` are commented out; do not treat them as active job definitions.
- `jetsam` is defined twice in the source reference; this inventory counts its identifier once. The duplicate needs reconciliation in the jobs source, not silently carried into PM Education.
- `police`, `sams`, `bus`, `trucker`, `tow`, `vineyard`, and other broad entries are included because they appear in the source; whether they remain in the final live server jobs configuration must be checked before implementation.
- The original `jobs.lua` is planning reference data, not a course catalog. Do not infer courses or eligibility rules from grades or job types alone.

## PM Education planning principles (discussion only)

- One shared QBCore education/examination engine may support multiple institutions, instructors, campuses, agencies, and professions.
- Keep reusable course definitions separate from physical instructor NPCs/locations; a course may be offered at more than one location.
- Training/exam completion and certification records should be distinguishable from actual job assignment or promotion. A passing exam should not automatically grant a job grade unless explicitly designed and approved later.
- Potential integration with the six PS-MDT oversight interfaces remains subject to discussion.
- Existing PowerMoves RP standards: QBCore, qb-target, custom qb-inventory, ox_lib. No ox_target/ox_inventory migration.
- Do not edit the fork's root README or begin feature implementation until the design discussion is complete.
