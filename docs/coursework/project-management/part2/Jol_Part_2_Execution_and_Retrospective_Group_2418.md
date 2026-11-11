Jol Agile Project Execution and Retrospective

Intercity Passenger Travel and Parcel Delivery in Kazakhstan

Team Project 2 Part 2
Final Exam Submission
Group SE-2418  |  Team 1

| Team member | Specialist contribution |
| --- | --- |
| Dilnaz Kairkulova | Product requirements and feedback |
| Bekassyl Zhaksylyk | iOS and maps |
| Diyar Zholdubayev | Backend and security |
| Aizada Sembayeva | Quality assurance and coordination |
| Zere Amantai | UI and UX design |

Scrum accountabilities rotate during the simulation; the rotation is documented in Section 5.

Course Title: Project Management
Instructor: Smagulova Karina
Date of Submission: 11 November 2026
Astana IT University

## Table of Contents

| Section | Page |
| --- | --- |
| 1 Sprint Execution Summary | 3 |
|    Sprint 1 / Sprint 2 / Sprint 3 / Sprint 4 | 3 / 4 / 5 / 6 |
| 2 Sprint Review and Increment Demonstration | 7 |
|    Graphical seat selection demonstration | 8 |
| 3 Sprint Retrospective | 9 |
| 4 Agile Metrics and Performance Evaluation | 10 |
|    Performance interpretation | 11 |
| 5 Team Collaboration Reflection | 12 |
|    Collaboration and lessons learned | 13 |
| 6 Final Report Presentation | 14 |
|    Parcel workflow demonstration | 15 |
|    Acceptance and evidence index | 16 |
| 7 References | 17 |

## Simulation basis

This report presents the academic execution simulation required by Part 2. Sprint outcomes, obstacles, review feedback and numerical results below are constructed scenario data. They describe the exercise, not actual field trials, government verification or production operations. Visuals are demonstration artefacts. No real personal identity data is used.

The four Part 1 Sprints and their story estimates are retained. They are replayed as logical Sprint cycles for the Week 10 submission; the original October to December product forecast is not presented as elapsed history. Story carry-over and role rotation are explicit.

## 1 Sprint Execution Summary

## Sprint 1 Accounts identity and trip setup

The Sprint Goal was to allow an authorised driver to publish a trip. The starting backlog contained US01 access (8 points), US02 identity and consent (8), US03 addresses and pins (8), and US04 trip publication (5): 29 points in total. This order follows the dependency from access to trips and then reservations [1]. Practices are adapted to the project context [2].

| Story | Scenario result | Points Done |
| --- | --- | --- |
| US01 | Registration and recovery scenarios accepted | 8 |
| US02 | Provider-dependent story carried to Sprint 2 | 0 |
| US03 | Confirmed pins and manual entry accepted | 8 |
| US04 | Stable seat and cargo inventory accepted | 5 |

## Obstacle and adaptation

In the exercise, provider access was unavailable. Diyar separated the provider response contract from the account workflow. Synthetic verified, refused and unavailable responses supported integration discussions. The team did not count a valid IIN format or a mocked response as a real identity check. US02 remained outside Done because its agreed exercise acceptance review was incomplete.

The Product Owner kept identity as P0. The Developers removed optional profile decoration and prepared the refusal scenario for the next Sprint. Denied location permission also led to a manual-address path rather than a forced GPS requirement.

## Review and handover

The review scenario followed account access, manual pin confirmation and trip publication. The trip used four passenger seats, stable seat IDs and separate cargo limits. The retrospective action was to attach a dependency check to every provider-related story before Sprint selection. Completed work was 21 points; 8 points carried forward.

## 1 Sprint Execution Summary continued

## Sprint 2 Passenger booking

The Sprint Goal was to reserve a selected seat without duplicate confirmation. The baseline was US05 catalogue (5), US06 graphical seats (5), US07 transactional booking (8), and US08 cancellation (3): 21 points. Adding US02 from Sprint 1 raised the commitment to 29 points, with no increase in the original estimates.

| Story | Scenario result | Points Done |
| --- | --- | --- |
| US02 | Synthetic identity contract and refusal exercise accepted | 8 |
| US05 | Route and date filtering accepted | 5 |
| US06 | Labelled front and rear seat map accepted | 5 |
| US07 | Hold and confirmation scenario accepted | 8 |
| US08 | Eligible cancellation scenario accepted | 3 |

## Obstacle and adaptation

The simulated review exposed two problems: users confused front and rear positions, and an old seat view could remain visible after another passenger confirmed. Zere added position labels and status text. Bekassyl specified refresh after a conflict. Diyar kept the server decision authoritative instead of trusting the displayed seat colour.

A five-minute hold protected selection. A retry used the same request identity; expiry released a seat; cancellation released it only once. The driver seat stayed unavailable. These are exercise acceptance outcomes rather than a claim of deployed booking behaviour.

## Review and process improvement

Two synthetic clients requested A1. The accepted scenario allowed one confirmation and returned an occupied state to the other. A hypothetical stakeholder asked for explicit “front passenger” and “rear left” labels. The team accepted that change within US06. The retrospective action was to agree response examples before parallel UI and backend tasks. All 29 committed points reached Done in the simulation.

## 1 Sprint Execution Summary continued

## Sprint 3 Parcel delivery and routing

The Sprint Goal was to agree parcel delivery within capacity and route limits. The baseline comprised US09 proposals (5), US10 multiple-parcel capacity (8), US11 routing and detour (8), US12 declarations and handover (5), and US15a incident reporting (5): 31 points. This follows the five-member final Part 1 backlog, including the split of US15.

| Story | Scenario result | Points Done |
| --- | --- | --- |
| US09 | Size weight category and stops accepted | 5 |
| US10 | Multi-parcel capacity exercise accepted | 8 |
| US11 | Unavailable-route case carried to Sprint 4 | 0 |
| US12 | Declaration refusal and handover accepted | 5 |
| US15a | Restricted incident scenario accepted | 5 |

## Obstacle and adaptation

An unavailable driving route made a parcel look suitable if a missing value was treated as zero detour. The team rejected this shortcut. Suitability became unknown until directions were available. US11 did not meet its full acceptance criteria and its entire 8 points carried over. Other accepted stories used a fixed route fixture so the capacity and handover scenarios remained independent.

Parcel acceptance checked total weight and available cargo space while retaining passenger luggage allowance. Two small parcels could be accepted, but a further parcel exceeding the limit was refused. Categories requiring refusal could not proceed to handover. These controls support accountability, not inspection of the actual contents.

## Review and retrospective action

A hypothetical driver wanted the extra kilometres displayed before acceptance. The Product Owner retained that requirement and prioritised the missing-route case in Sprint 4. The team agreed to include unavailable responses in every external-service fixture. Completed work was 23 points; 8 points carried forward.

## 1 Sprint Execution Summary continued

## Sprint 4 Tracking and integrated validation

The final goal was to demonstrate a complete passenger and parcel journey with controlled location access. The baseline contained US13 statuses (5), US14 tracking (8), US15b readability (3), and US16 observed-task exercise (5): 21 points. US11 added 8 carried points, making 29 committed points.

| Story | Scenario result | Points Done |
| --- | --- | --- |
| US11 | Detour and unknown-route fixtures accepted | 8 |
| US13 | Authorised status sequence accepted | 5 |
| US14 | Participant access stale and stop scenarios accepted | 8 |
| US15b | Contrast labels and notices accepted | 3 |
| US16 | Synthetic task matrix and critical checks accepted | 5 |

## Obstacle and adaptation

The exercise introduced network loss while tracking. Instead of showing an old point as current, the interface marked updates older than 60 seconds as stale. Sharing stopped at completion and access was limited to accepted participants. Location denial retained manual trip information. Permission decisions were considered part of the user journey [3].

A parcel declaration prompt caused one synthetic task failure. Another failure involved an unclear filter. The team logged both as future usability improvements without changing their results. The synthetic task matrix recorded 8 successful attempts out of 10; no actual participant sessions are claimed.

## Review and closure

The review replayed a seat conflict, two accepted parcels, an overload refusal, a route failure, handover confirmation and restricted tracking. All 29 points reached Done in the exercise. Future work retained payments, Android and segment-based seat reuse outside this scope. The final backlog preserved open usability improvements rather than describing the product as universally accepted.

## 2 Sprint Review and Increment Demonstration

The review was simulated as a stakeholder walkthrough. Each increment added a usable journey outcome: trip publication in Sprint 1, seat booking in Sprint 2, parcel agreement in Sprint 3, and connected tracking and validation in Sprint 4. Reviews inspect the product; retrospectives inspect the team process [1].

| Step | Demonstration and review criterion |
| --- | --- |
| 1 Account and trip | Synthetic identity outcomes; rejected identity cannot publish. Driver sets seats and cargo limits. |
| 2 Passenger seat | Choose A1 then replay a competing request. Only one confirmation is accepted. |
| 3 Parcel proposal | Enter category size weight and endpoints; selected driver accepts or rejects. |
| 4 Capacity and route | Accept two parcels; refuse overload; show unknown suitability for missing directions. |
| 5 Journey and handover | Confirm pickup and delivery; show location only to participants; stop at completion. |

## Hypothetical stakeholder feedback

Passenger: “Show whether my place is in front or at the back.” Decision: retain position labels and occupied text. Driver: “Show extra distance before I accept.” Decision: keep the route check as an acceptance gate. Sender: “Explain why the declaration is required.” Decision: add a concise purpose sentence to the next backlog item.

## Review outcome

The exercise accepted the integrated scenario against the stated criteria. It did not claim live SMS, official IIN-provider approval or physical delivery. The demonstrator keeps a state checklist and explains which transition each visual represents. New requests enter the backlog with an owner, estimate and acceptance examples; they do not silently expand the Sprint Goal.

## 2 Graphical Seat Selection Demonstration

Figure 1. Jol seat-selection concept used in the simulated review. Fictional driver and trip details. This is a generated interface mockup, not a screenshot proving implementation.

The left state shows four available passenger seats. The right state shows A1 front passenger and B1 rear left occupied; B2 rear centre and B3 rear right remain available. The driver seat is never bookable and is excluded from the passenger count.

Walkthrough: point to A1, request a hold, confirm it, then replay another user selecting the same seat. The required response is a conflict followed by an updated occupied label. A visual alone cannot prove transaction safety; the scenario acceptance record is separate.

The change from colour-only seat states to explicit labels illustrates adaptation after review feedback. The native interface uses readable contrast and non-colour cues, informed by accessibility guidance [4].

## 3 Sprint Retrospective

The retrospective used three prompts: what helped, what caused delay, and what we would change. The team selected one action per Sprint and evaluated it in the following simulated cycle. This keeps reflection connected to a measurable process change.

| No. | What went well | Problem | Action and follow-up |
| --- | --- | --- | --- |
| 1 | Independent trip and address stories progressed | Provider dependency unclear | Diyar adds a dependency checklist; S2 contract reviewed before selection. |
| 2 | Seat labels clarified user choice | UI and API assumptions differed | Bekassyl and Diyar agree response examples; S3 proposal contract starts with fixtures. |
| 3 | Capacity and refusal cases remained explicit | Missing directions reached review late | Bekassyl adds unavailable-route fixtures; S4 demonstrates unknown suitability. |
| 4 | One integrated journey connected roles | Task instructions exposed two difficulties | Zere owns revised filter and declaration wording; next cycle target remains 8/10 or higher. |

## Future improvements

Reserve review capacity at Planning and finish review before starting new work. Keep one primary item per person in progress. Pair a reviewer with each risk-sensitive task and identify the next action for blockers lasting one working day. Bring user feedback into the seat-map review before the final cycle.

Do not lower privacy or booking criteria to improve velocity. A story with an unfinished critical case remains outside Done. Use smaller stories where possible, but split them before commitment with independent value and tests; do not award partial points retrospectively. Security review stays part of the workflow [5].

## 4 Agile Metrics and Performance Evaluation

| No. | Baseline | Carry in | Committed | Done | Carry out |
| --- | --- | --- | --- | --- | --- |
| 1 | 29 | 0 | 29 | 21 | 8 |
| 2 | 21 | 8 | 29 | 29 | 0 |
| 3 | 31 | 0 | 31 | 23 | 8 |
| 4 | 21 | 8 | 29 | 29 | 0 |

Table 1. Synthetic story-point ledger. Committed = baseline + carry in. Carry out = committed − Done. Velocity counts only stories meeting Done. Baseline totals 102 points; the 118 commitment total includes 16 repeated carried points, so it is not unique scope.

Figure 2. Synthetic velocity is 21, 29, 23 and 29 points. Average velocity is 25.5 points per Sprint.

Completion against commitment is 72.4%, 100%, 74.2% and 100%. Changes reflect blocked acceptance and carry-over, not a simple rise in productivity. Story points measure relative complexity and uncertainty; they are not hours, individual output or a basis for comparing teams.

## 4 Burn Down and Performance Interpretation

Figure 3. Remaining work drops only when a full story meets Done. Day 0 is the Sprint commitment; Day 10 closes at zero.

US13 closes on Day 3 (5 points), US11 on Day 5 (8), US14 on Day 7 (8), US16 on Day 9 (5), and US15b on Day 10 (3). No scope is added after Day 0. Plateaus represent review and validation time rather than lack of activity. The late completion pattern suggests that review should begin earlier.

## Progress tracking and interpretation

The simulated board uses Backlog, Ready, In Progress, Review and Done, plus a Blocked label. Each record includes story ID, owner, reviewer, estimate and acceptance link. The evidence index on page 16 supplies example record identifiers for this board. This is an exercise snapshot, not an exported live tracker. GitHub Projects links roadmap and issue information [6].

All 102 unique points close by the final cycle, but US02 and US11 each slip once. Therefore final scope completion does not imply reliable Sprint forecasting. The next plan should use the 21–29 point observed exercise range cautiously, check external dependencies early, and retain contingency. User focus and stable priorities are useful improvement lenses [7].

## 5 Team Collaboration Reflection

## Rotating Scrum accountabilities

Specialist skills remain stable, while Scrum accountabilities rotate. Product Owner means ordering value and acceptance; Scrum Master means facilitating inspection and removing process obstacles; Developers collectively create and evaluate the increment. Scrum does not require rotation, but the coursework does, so we apply it as an educational arrangement [1].

| No. | Product Owner | Scrum Master | Developers |
| --- | --- | --- | --- |
| 1 | Dilnaz | Aizada | Bekassyl, Diyar, Zere |
| 2 | Bekassyl | Diyar | Dilnaz, Aizada, Zere |
| 3 | Aizada | Zere | Dilnaz, Bekassyl, Diyar |
| 4 | Diyar and Zere in successive sessions | Dilnaz then Bekassyl | Remaining three members in each session |

Sprint 4 sessions A and B rotate at a documented handover checkpoint. Session A: Diyar is Product Owner, Dilnaz is Scrum Master, and Bekassyl, Aizada and Zere are Developers. Session B: Zere is Product Owner, Bekassyl is Scrum Master, and Dilnaz, Diyar and Aizada are Developers. At every moment there is one accountable Product Owner and one Scrum Master, not joint ownership.

This schedule gives every member experience as Product Owner, Scrum Master and Developer. Technical specialists support the temporary role-holder without taking away their decision responsibility. A handover note records the Sprint Goal, backlog order, open decisions and unresolved blockers. The goal remains unchanged at the checkpoint.

## How roles evolved

The exercise moved product decisions beyond one person. Bekassyl practised value prioritisation; Diyar practised facilitation; Aizada practised scope decisions; Zere practised trade-offs; Dilnaz practised delivery and review. Developer contributions include design, scenario testing and documentation as well as coding.

## 5 Collaboration and Lessons Learned

The main collaboration lesson was to agree on observable behaviour before parallel work. Zere explained the seat states, Bekassyl described the interface response, Diyar specified the server decision, Aizada challenged failure cases, and Dilnaz checked whether the result met the user need. This reduced ambiguous handoffs in the exercise.

## Communication and conflict resolution

The Daily Scrum focused on the Sprint Goal, the next action and help needed. Telegram carried short coordination messages; Google Meet supported reviews. Decisions were copied into the issue so that absence from a call did not remove access to the reasoning. Each issue named an owner and a reviewer.

A conflict arose in the scenario between keeping a quick route estimate and blocking acceptance when directions were unavailable. The team returned to the agreed criterion: suitability must not be invented. The Product Owner reordered work; Developers chose a fixture-based fallback for independent tests; the Scrum Master made the dependency visible.

## Agile values in the exercise

Individuals and interactions: discuss unclear seat positions directly. Working software: review the reservation behaviour, not only its picture. Customer collaboration: use hypothetical passenger, sender and driver feedback to update criteria. Responding to change: carry incomplete stories honestly instead of silently weakening acceptance. These choices apply the values in the Agile Manifesto [8].

## Lessons to carry forward

Rotation needs explicit handovers. External dependencies need an owner before commitment. Review time must be budgeted alongside implementation. Small end-to-end stories expose problems earlier than isolated screens. Team metrics should improve decisions, not rank people. Mock identity responses must remain clearly separate from lawful real-person verification; personal data access requires its own review [9], [10].

## 6 Final Report Presentation

## Project journey and key takeaways

The Part 1 plan defined the product, backlog, four Sprints and acceptance criteria. Part 2 replayed execution, introduced obstacles, held reviews, recorded retrospective actions and evaluated the result through a consistent point ledger. The product journey expanded from trip publication to seat booking, parcel agreement and tracking.

Two stories missed their original Sprint: identity integration and routing. Keeping both outside Done made the metrics more useful. Their carry-over exposed provider and failure-state dependencies, while the retrospective actions described how the next cycle addressed them. The strongest lesson is that adaptation changes the plan while preserving quality criteria.

## Final defence sequence

| Presenter | Focus and supporting artefact |
| --- | --- |
| Dilnaz | Product Goal, scope, backlog value and passenger need. |
| Aizada | Scrum cadence, Sprint deviations, retrospective and acceptance. |
| Bekassyl | Seat states and route behaviour; Figure 1 walkthrough. |
| Diyar | Capacity, identity references and controlled data access. |
| Zere | UI feedback, parcel workflow and role rotation reflection. |

The defence opens with the user journey, explains the four increments, demonstrates a seat conflict and parcel refusal, then interprets velocity and the burn-down. The team closes with one process improvement per Sprint and future backlog priorities. Presentation material must label the numerical dataset and stakeholder feedback as simulated.

The next backlog keeps clearer declaration wording, filter guidance, richer reviews and additional car layouts. Payments, Android and segment-based seat reuse require separate estimates. Operating notes describe permitted roles, stale-location handling, refusal procedures and support escalation.

## 6 Parcel Workflow Demonstration

## Demonstration form and decision states

| Field | Synthetic example |
| --- | --- |
| Trip | Almaty to Taldykorgan; chosen published driver |
| Parcel category | Clothing and personal items |
| Size | Small box; 40 × 30 × 20 cm |
| Weight | 3 kg |
| Collection and delivery | Confirmed map pins; private exact addresses |
| Contents declaration | Sender confirms allowed contents |
| Driver decision | Accept / Reject after capacity and route checks |

Figure 4. Textual interface prototype for the parcel proposal. All values are fictional and describe demonstration input, not an actual delivery.

| State | Allowed next step |
| --- | --- |
| Draft | Validate category, size, weight, pins and declaration |
| Proposed | Only the selected driver accepts or rejects |
| Accepted | Reserve cargo and arrange pickup |
| Picked up | Record confirmation and show active delivery status |
| Delivered | Record receipt and stop journey sharing |
| Refused or reported | Restrict access to the incident and authorised records |

Walkthrough: propose the 3 kg parcel, accept it within capacity, then propose an item that exceeds the remaining limit. The second acceptance is refused. Replay the same request to show that capacity is not consumed twice. When directions are unavailable, display unknown suitability instead of zero extra kilometres. MapKit provides the native routing interface [11].

The driver and sender verification results link the agreement to accountable accounts. Raw IINs, contacts and precise addresses do not appear in the public catalogue. Verification does not inspect parcel contents or guarantee safe travel.

## 6 Acceptance and Evidence Index

| ID | Exercise evidence | Result and location |
| --- | --- | --- |
| SIM01 | Access and trip walkthrough | Accepted; Sprint 1, page 3 |
| SIM02 | Seat conflict hold expiry and cancellation | Accepted; Sprint 2, page 4; Figure 1 |
| SIM03 | Two parcels and overload refusal | Accepted; Sprint 3, page 5; Figure 4 |
| SIM04 | Unknown directions and detour limit | Deferred S3; accepted S4, page 6 |
| SIM05 | Participant access stale point and stop | Accepted; Sprint 4, page 6 |
| SIM06 | Synthetic usability matrix | 8 of 10; summary below |
| SIM07 | Role handover record | All members rotate; page 12 |

| Synthetic user | Seat task | Parcel task |
| --- | --- | --- |
| U1 | Success | Success |
| U2 | Success | Success |
| U3 | Success | Failed: declaration prompt |
| U4 | Failed: route filter | Success |
| U5 | Success | Success |

Table 2. Constructed task outcomes: four seat successes plus four parcel successes = eight successes in ten attempts (80%). The matrix illustrates evaluation; it is not an interview or observation record. Five hypothetical users cannot establish market demand.

Critical acceptance scenarios include one confirmed booking per seat, no cargo overload, denied unauthorised tracking and no raw IIN exposure in public data. In the simulation these cases are assigned an accepted result after review; they are not claimed as outputs from automated test execution. A real run would attach timestamped logs, fixture versions and anonymised observations. Firebase emulators support repeatable synthetic-data testing [12]; attestation complements rather than replaces authorisation [13].

## 7 References

References use IEEE numbering in order of first citation. Nine of the thirteen dated or undated entries were published in 2022 or later; access dates below are retained from the source bibliography. The Scrum Guide defines the underlying accountabilities and events, while the assignment defines the educational simulation and rotation requirement.

[1] K. Schwaber and J. Sutherland, The Scrum Guide. Nov. 2020. [Online]. Available: https://scrumguides.org/scrum-guide.html. Accessed: Oct. 23, 2026.

[2] Project Management Institute, The Future of Project Work: Moving Past Office-Centric Models, Pulse of the Profession 2024, Feb. 2024. [Online]. Available: https://www.pmi.org/learning/thought-leadership/future-of-project-work. Accessed: Oct. 23, 2026.

[3] Apple, “What’s new in location authorization,” WWDC24, session 10212, 2024. [Online]. Available: https://developer.apple.com/videos/play/wwdc2024/10212/. Accessed: Oct. 23, 2026.

[4] World Wide Web Consortium, Web Content Accessibility Guidelines (WCAG) 2.2, W3C Recommendation, Dec. 12, 2024. [Online]. Available: https://www.w3.org/TR/2024/REC-WCAG22-20241212/. Accessed: Oct. 23, 2026.

[5] M. Souppaya, K. Scarfone, and D. Dodson, “Secure Software Development Framework Version 1.1,” NIST SP 800-218, Feb. 2022, doi: 10.6028/NIST.SP.800-218. [Online]. Available: https://csrc.nist.gov/pubs/sp/800/218/final. Accessed: Oct. 23, 2026.

[6] GitHub, “Roadmaps in Projects are now generally available,” GitHub Changelog, Mar. 23, 2023. [Online]. Available: https://github.blog/changelog/2023-03-23-roadmaps-in-projects-are-now-generally-available/. Accessed: Oct. 23, 2026.

[7] D. DeBellis et al., DORA Accelerate State of DevOps 2024 Report. Google, 2024. [Online]. Available: https://research.google/pubs/dora-accelerate-state-of-devops-2024-report/. Accessed: Oct. 23, 2026.

## 7 References continued

[8] K. Beck et al., “Manifesto for Agile Software Development,” 2001. [Online]. Available: https://agilemanifesto.org/. Accessed: Oct. 23, 2026.

[9] Republic of Kazakhstan, “On Personal Data and their Protection,” Law No. 94-V, May 21, 2013, arts. 7, 8, 12 and 16, consolidated text. [Online]. Available: https://old.adilet.zan.kz/rus/docs/Z1300000094. Accessed: Oct. 23, 2026.

[10] Information Security Committee of Kazakhstan, “State service for control of access to personal data” [in Russian], Aug. 2, 2023. [Online]. Available: https://www.gov.kz/org/infsecurity/press/article/details/130936. Accessed: Oct. 23, 2026.

[11] Apple, “Meet MapKit for SwiftUI,” WWDC23, session 10043, 2023. [Online]. Available: https://developer.apple.com/videos/play/wwdc2023/10043/. Accessed: Oct. 23, 2026.

[12] Google, “Introduction to Firebase Local Emulator Suite,” Firebase Documentation, n.d. [Online]. Available: https://firebase.google.com/docs/emulator-suite. Accessed: Oct. 23, 2026.

[13] T. Crowe, “What’s new from Firebase at Google I/O 2022,” Firebase Blog, May 11, 2022. [Online]. Available: https://firebase.blog/posts/2022/05/whats-new-at-google-io. Accessed: Oct. 23, 2026.

Source assignment: Team Project 2 Part 2 for Final Exam, course handout supplied by the instructor. Its deliverables are execution summary, increment review, retrospective, Agile metrics, collaboration reflection and final presentation. This report uses its permission to simulate execution and hypothetical stakeholder feedback.
