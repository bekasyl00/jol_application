## Jol Agile Project Plan

Intercity Passenger Travel and Parcel Delivery in Kazakhstan

Team Project 2 Part 1

End Term Submission

Agile Project Planning

Team Jol   |   Group 2418

| Team member | Project role |
| --- | --- |
| Dilnaz Kairkulova | Product Owner and user research |
| Bekassyl Zhaksylyk | Developer for iOS and maps |
| Diyar Zholdubayev | Developer for backend and security |
| Aizada Sembayeva | Scrum Master and quality assurance |

Course Title: Project Management

Instructor: Smagulova Karina

Date of Submission: 23 October 2026

## Table of Contents

1 Project Vision and Goals	3

   Project scope and graphical seat selection	4

2 Agile Framework Selection	5

   Key practices and quality criteria	6

3 Sprint Planning and Roadmap	7

   Product backlog for access and booking	8

   Product backlog for parcels and routes	9

   Product backlog for delivery and assurance	10

   Sprint 1 Accounts identity and trip setup	11

   Sprint 2 Passenger booking	12

   Sprint 3 Parcel delivery and routing	13

   Sprint 4 Tracking and integrated validation	14

   Risks dependencies and progress measures	15

4 Team Roles and Responsibilities	16

5 Tools and Techniques	17

6 Reflection on Agile Values	18

7 References	19

Planning basis

This report defines the product, delivery approach and acceptance criteria for Jol. Dates, effort estimates and role allocations form a proposed academic project baseline. They are forecasts for planning, rather than records of work performed.

The delivery window is 26 October to 20 December 2026. The course requirement to submit Part 1 by the end of Week 8 remains separate from this illustrative product schedule.

## 1 Project Vision and Goals

### 1 1 Project description

Jol is an iOS platform for intercity passenger journeys and parcel delivery in Kazakhstan. Passengers choose published trips and specific seats; senders offer parcels to suitable drivers. Drivers manage passenger reservations and cargo capacity within one journey. The product goal is a clear agreement before travel begins.

A passenger searches by origin, destination and date, then selects a car seat. A sender specifies collection and delivery points, contents and size. An account can use passenger or sender functions and apply for driver access through distinct, clearly labelled actions.

### 1 2 Product goals

We will make seat availability explicit, prevent duplicate reservations, and let users arrange a journey without broadcasting their phone number to multiple drivers. Front and rear seats must be individually identifiable. Parcel acceptance must respect both remaining luggage space and the passenger commitments of the trip.

We will support address search, map pins, driving distance, estimated duration and additional driving distance for parcel stops. SwiftUI and Apple MapKit provide the native map interface; MapKit supports SwiftUI annotations and overlays [1]. The design uses MKLocalSearchCompleter, MKDirections and MapPolyline, without developing a separate navigation engine.

### 1 3 Positioning and expected value

Jol’s intended distinction from alternatives such as inDrive and Yandex Go is the combination of graphical seat booking, a searchable driver catalogue and a structured parcel workflow. Communication begins inside the chosen booking or proposal, instead of exposing a request to unsolicited calls. This is a product positioning hypothesis to test with users, not a claim that competitors lack every feature or that any platform can eliminate incidents.

Expected outputs are the iOS app, server workflows, test evidence and operating notes. Success is measured by booking consistency, controlled data access and observed user task completion.

### 1 4 Project scope and graphical seat selection

Scope covers accounts, identity checks, published trips, seat booking, parcel proposals, maps, active tracking and incident reports. Payments, Android, custom navigation, OSRM and H3 are excluded. A reservation creates a booking confirmation; it does not process payment.

### Seat selection example

| Left side | Centre | Right side |
| --- | --- | --- |
| Driver / Unavailable | Front of vehicle | A1 front passenger / Occupied |
| B1 rear left / Available | B2 rear centre / Selected by you | B3 rear right / Available |

Figure 1. Five-seat car example. The driver seat is not bookable. Text labels make each state understandable without colour.

Selecting a seat requests a five-minute server hold; confirmation makes it occupied. Expiry or eligible cancellation releases it. The map also labels other users’ holds, blocked seats and stale data. Confirmation rechecks availability. A vehicle layout cannot change while reservations are active.

### Identity and parcel accountability

Drivers and senders must verify identity through their Individual Identification Number (IIN), consent and a lawful provider. A number alone is not proof of identity. Public profiles show only the verification result. Declarations and handover records link a parcel incident to an account without revealing its IIN.

Kazakhstan’s consent and data-storage requirements govern the design [2]. Protected identity storage will be located in Kazakhstan; Firebase receives minimum approved workflow data and a verification reference. Linkable records and cross-border transfers require data-flow review. Access to government data follows the applicable consent process, including KDP where required [3].

## 2 Agile Framework Selection

### 2 1 Framework chosen

We choose Scrum with four two-week Sprints. The framework organises work around a Product Goal, a Sprint Goal and a usable Increment. Its accountabilities are Product Owner, Scrum Master and Developers, with inspection and adaptation built into the delivery cycle [4]. Our team will use a visual task board within Scrum to reveal blocked work and review queues.

### 2 2 Why Scrum fits Jol

Jol combines user experience decisions with transaction, routing and identity risks. A seat may look available while another user is reserving it; a convenient parcel stop may create an unacceptable detour. Short cycles let us demonstrate these interactions and adjust the backlog before adding more dependent features. A two-week review also gives all four students a regular coordination point.

| Approach | Assessment for this project |
| --- | --- |
| Scrum | Chosen: shared goals and scheduled reviews support integrated passenger and parcel journeys. |
| Kanban | A useful board for flow, but continuous intake alone gives our course team fewer fixed demonstration points. |
| Predictive delivery | Useful for the fixed report deadline; less suitable for freezing detailed seat and routing behaviour before user feedback. |

Our choice is contextual. PMI’s 2024 research supports adapting practices to the work and investing in team capability; it does not establish that Agile always performs best [5]. We retain clear deadlines while adapting backlog details.

### 2 3 How we will adapt

Our Product Goal is an intercity journey with a reserved seat or documented parcel agreement. Reviews examine this journey. Developers select feasible work; the Product Owner orders future items by value, risk and dependency. Mid-Sprint requests are discussed before changing the agreed goal.

### 2 4 Key practices and quality criteria

The following cadence is our team’s working agreement. Each Sprint lasts fourteen calendar days and uses ten working days. The meeting allowance is six hours per person per Sprint; weekends do not add hidden development capacity.

| Practice | Cadence and intended result |
| --- | --- |
| Sprint Planning | 60 minutes at the start: choose a goal, inspect dependencies and select work within capacity. |
| Daily Scrum | 15 minutes each working day: coordinate progress toward the goal and identify help needed. |
| Refinement | Two 30-minute sessions: clarify the next stories, acceptance examples and estimates. |
| Sprint Review | 45 minutes on the final working Friday: demonstrate the journey and record user feedback. |
| Retrospective | 45 minutes after the review: choose one measurable improvement for the next Sprint. |

### Definition of Ready

A story needs a user outcome, acceptance examples, an estimate, a collaborator and visible dependencies. Split large stories before selection. Identity access, map coverage and device availability must be checked rather than assumed.

### Definition of Done

A story meets its acceptance criteria, passes relevant tests and device checks, receives peer review and links evidence to its issue. Include denied access, retries and failure states. Duplicate bookings, unauthorised disclosure and invalid parcel acceptance prevent completion.

Security practices apply throughout delivery [6]. WCAG 2.2 contrast and non-colour cues guide design alongside native iOS checks [7]. Test light and dark appearance, larger text and keyboard dismissal. These benchmarks do not imply full web-standard conformance for an iOS app.

## 3 Sprint Planning and Roadmap

Four two-week Sprints each combine design, implementation and testing. Dates are planning assumptions; confirm the academic calendar and external identity access at kickoff.

| Phase and dates | Focus | Review outcome |
| --- | --- | --- |
| Sprint 1 / 26 Oct to 8 Nov | Accounts, identity, addresses, trips | An authorised driver publishes a trip |
| Sprint 2 / 9 to 22 Nov | Passenger catalogue and seats | A passenger reserves a specific seat |
| Sprint 3 / 23 Nov to 6 Dec | Parcels, capacity and routing | A sender and driver agree a suitable delivery |
| Sprint 4 / 7 to 20 Dec | Tracking, incidents and validation | A complete journey with an evidence record |

### Capacity and estimates

Capacity is 16 hours per person per week: 128 person-hours per Sprint, comprising 80 task hours, 24 event hours and 24 reserve hours. The four-Sprint total is 512 hours: 320 tasks, 96 events and 96 reserve. Task estimates include review and testing.

Points represent complexity and uncertainty, not hours or measured velocity. Forecasts of 29, 21, 26 and 26 points total 102. Reassess each Sprint using evidence and individual availability.

### Dependency sequence and scope decisions

Identity enables trips; trip inventory enables reservations and parcels; accepted agreements enable tracking. Check identity access, lawful storage and route coverage in Sprint 1.

Reviews: 6 November, 20 November, 4 December and 18 December. The final review includes operating instructions and the next backlog; timeboxes end on the following Sundays.

### 3 1 Product backlog for access and booking

P0 identifies identity, integrity or safety controls; P1 identifies core user journeys. Order depends on prerequisites as well as priority.

#### US01   P0   8 points   Sprint 1

As an account holder, I want phone and password access with SMS verification so that I control my account.

Acceptance: Minimum six characters; registration and recovery require valid proof; expired codes fail; reset revokes prior sessions.

#### US02   P0   8 points   Sprint 1

As a driver or sender, I want identity verification using IIN and consent so that my transactions are accountable.

Acceptance: Number entry alone never verifies identity; failed checks block restricted actions.

#### US03   P1   8 points   Sprint 1

As a traveller or sender, I want address search and confirmed pins so that my journey uses the intended locations.

Acceptance: An address change invalidates its pin; denied GPS permits manual entry.

#### US04   P1   5 points   Sprint 1

As a driver, I want to publish my route, departure, seats and cargo limits so that users understand my trip.

Acceptance: Exclude the driver seat; retain stable seat IDs; reject invalid capacity.

#### US05   P1   5 points   Sprint 2

As a passenger or sender, I want route and date filters so that I can choose a trip without unsolicited calls.

Acceptance: Respect filters; exclude contacts and exact private addresses from public listings.

#### US06   P1   5 points   Sprint 2

As a passenger, I want graphical front and rear seats so that I can choose where to sit.

Acceptance: Label selected, held, occupied and unavailable states; prevent selection of occupied seats.

### 3 2 Product backlog for parcels and routes

#### US07   P0   8 points   Sprint 2

As a passenger, I want a confirmed seat so that nobody else can book the same place.

Acceptance: One concurrent request wins; five-minute holds expire; retries do not duplicate bookings.

#### US08   P1   3 points   Sprint 2

As a passenger, I want eligible cancellation so that another traveller can use my seat.

Acceptance: Release it exactly once before departure; reject self-service cancellation after departure.

#### US09   P1   5 points   Sprint 3

As a verified sender, I want to propose a parcel to a selected driver so that we agree before handover.

Acceptance: Include size, weight and stops; only that driver can accept or reject.

#### US10   P0   8 points   Sprint 3

As a driver, I want to accept multiple parcels within capacity so that passenger and cargo commitments remain compatible.

Acceptance: Concurrent acceptance respects capacity; one parcel cannot be assigned to two drivers.

#### US11   P1   8 points   Sprint 3

As a driver, I want road distance, duration and detour estimates so that I can judge a parcel against trip limits.

Acceptance: Evaluate all stops; missing directions mean unknown suitability, not invented distance.

#### US12   P0   5 points   Sprint 3

As a sender or driver, I want declarations and handover records so that parcels are traceable and unsuitable contents are refused.

Acceptance: Block prohibited categories; require declarations, refusal records and confirmation at pickup and delivery.

Seat and cargo inventories remain separate. Parcels cannot consume passenger seats or the agreed luggage allowance.

### 3 3 Product backlog for delivery and assurance

#### US13   P1   5 points   Sprint 4

As a passenger or sender, I want clear journey statuses so that I understand the next step.

Acceptance: Allow only authorised transitions; record actor and time; repeated updates remain idempotent.

#### US14   P1   8 points   Sprint 4

As an accepted participant, I want consent-based location updates so that I can follow the active journey.

Acceptance: Restrict access; label stale points; stop sharing when the journey ends.

#### US15   P0   8 points   Sprint 4

As a user, I want readable screens and private incident reporting so that I can use Jol and raise concerns.

Acceptance: Exclude raw IINs from public data and logs; restrict reports; check accessibility.

#### US16   P1   5 points   Sprint 4

As a stakeholder, I want observed passenger and parcel tests so that acceptance is based on behaviour.

Acceptance: Eight of ten user tasks succeed unaided; all critical transaction and privacy tests pass.

### Backlog prioritisation and deferred work

Order work by failure risk, user value, dependency and effort. P0 tests apply throughout; US15 consolidates the final audit. P2 enhancements follow the core acceptance criteria.

P2 backlog: richer reviews, chat attachments, additional vehicle layouts and seat reuse by journey segment. The baseline reserves seats for the whole trip. Payments, Android, OSRM and H3 require separate scope and estimates.

A change request identifies its affected story and acceptance criteria. Revise scope or dates when necessary; retain privacy and transaction tests.

### 3 4 Sprint 1 Accounts identity and trip setup

26 October to 8 November 2026. Goal: an authorised driver publishes a trip with confirmed points and capacity. US01–US04: 29 points, 80 task hours.

| Task and story | Hours by member | h | Resource |
| --- | --- | --- | --- |
| 1A US01 Validate login and reset contracts | D12 | 12 | Functions tests |
| 1B US01 Implement access forms and session checks | B6, A2 | 8 | Xcode and iPhone |
| 1C US02 Integrate identity result and protected access | D12 | 12 | Provider sandbox |
| 1D US02 Define consent, verification and exception flow | L12 | 12 | Identity policy |
| 1E US03 Implement search and map pin confirmation | B10, A2 | 12 | MapKit and iPhone |
| 1F US03 Check sample addresses and route coverage | L4, A4 | 8 | Route test matrix |
| 1G US04 Create trip and car layout form | B6, L2 | 8 | SwiftUI wireframe |
| 1H US04 Test seat and cargo inventory limits | A8 | 8 | Emulator tests |

L = Dilnaz; B = Bekassyl; D = Diyar; A = Aizada. Allocations are person-hours.

Dependencies: authorised identity access and lawful storage. Review on 6 November: show access and recovery, identity refusal, manual pins after GPS denial and trip publication. Test Almaty, Astana and Karaganda address pairs. A valid IIN format alone must never grant verified status.

Task loads: L18, B22, D24, A16 hours. Add six event hours per person; each remains within 32 hours. Provider waiting time is an external schedule risk.

### 3 5 Sprint 2 Passenger booking

9 to 22 November 2026. Goal: a passenger reserves a chosen seat without double booking. US05–US08: 21 points, 80 task hours.

| Task and story | Hours by member | h | Resource |
| --- | --- | --- | --- |
| 2A US05 Define filters and public listing fields | L8 | 8 | Catalogue examples |
| 2B US05 Implement trip search and result cards | B8 | 8 | SwiftUI and data |
| 2C US06 Build labelled graphical seat selection | B12 | 12 | Xcode and iPhone |
| 2D US06 Check seat states and accessibility | A8 | 8 | Device test script |
| 2E US07 Implement atomic holds and confirmation | D16 | 16 | Functions emulator |
| 2F US07 Test races, expiry and request retries | D4, A8 | 12 | Concurrency suite |
| 2G US08 Implement cancellation policy and endpoint | D4, L4 | 8 | Booking scenarios |
| 2H US08 Connect and test cancellation controls | B4, A4 | 8 | Two-client tests |

L = Dilnaz; B = Bekassyl; D = Diyar; A = Aizada. Allocations are person-hours.

The server atomically checks hold ownership and expiry. Expired holds count as available even before cleanup. Whole-trip reservations avoid seat reuse between stops. Review on 20 November: test simultaneous requests, expiry, stale screens, retry and cancellation; exactly one user obtains the seat.

Task loads: L12, B24, D24, A20 hours, plus six event hours each. Dependencies: accounts, trip inventory and shared server state. The driver seat and occupied front seat must remain unbookable.

### 3 6 Sprint 3 Parcel delivery and routing

23 November to 6 December 2026. Goal: a sender and driver agree a parcel delivery within capacity and route limits. US09–US12: 26 points, 80 task hours.

| Task and story | Hours by member | h | Resource |
| --- | --- | --- | --- |
| 3A US09 Specify proposal and driver decision flow | L8 | 8 | Parcel scenarios |
| 3B US09 Connect proposal form to trip details | B8 | 8 | SwiftUI and data |
| 3C US10 Implement atomic multi-parcel capacity | D12 | 12 | Functions emulator |
| 3D US10 Test overload, duplicate and race cases | D8, A4 | 12 | Capacity fixtures |
| 3E US11 Calculate routes, stops and detour | B12 | 12 | MKDirections |
| 3F US11 Validate corridor limits and route failures | L8, A4 | 12 | MapKit route cases |
| 3G US12 Implement declaration and handover records | D4, L4 | 8 | Policy and backend |
| 3H US12 Test refusal and confirmation scenarios | A8 | 8 | Parcel test scripts |

L = Dilnaz; B = Bekassyl; D = Diyar; A = Aizada. Allocations are person-hours.

MKDirections evaluates all pickups and drop-offs; MapPolyline displays the route. Check added distance against the current itinerary and total detour against the published base route. Respect driver and passenger limits. Missing directions mean unknown suitability. Passenger commitments cannot change silently.

Review on 4 December: accept two parcels, reject overload and excess detour, then record declaration, refusal and handover cases. Keep passenger luggage capacity reserved. IIN verification supports accountability; it cannot inspect contents or prevent every theft.

Task loads: L20, B20, D24, A16 hours, plus six event hours each. Dependencies: identity controls, protected points, shared capacity and valid route responses.

### 3 7 Sprint 4 Tracking and integrated validation

7 to 20 December 2026. Goal: participants follow a journey, confirm delivery and report incidents privately. US13–US16: 26 points, 80 task hours.

| Task and story | Hours by member | h | Resource |
| --- | --- | --- | --- |
| 4A US13 Implement journey status screens | B8 | 8 | Xcode and iPhone |
| 4B US13 Enforce status transition permissions | D8 | 8 | Functions tests |
| 4C US14 Connect tracking and participant access | B12, D4 | 16 | Core Location |
| 4D US14 Test background, stale and denied GPS | A8 | 8 | Two iOS devices |
| 4E US15 Audit data rules and incident handling | D12 | 12 | Security tests |
| 4F US15 Review consent, reporting and readability | L8, A4 | 12 | Device checklist |
| 4G US16 Run observed passenger and sender tasks | L8 | 8 | Five test users |
| 4H US16 Run integrated suite and assemble evidence | A8 | 8 | CI and test log |

L = Dilnaz; B = Bekassyl; D = Diyar; A = Aizada. Allocations are person-hours.

Request location for the active feature and respect denial [8]. Retain iOS 17 support and guard newer APIs. Mark updates older than 60 seconds as stale. Review on 18 December: test 30 minutes of tracking, screen locking, network loss and stopping after completion.

Five consenting users each attempt a seat booking and parcel proposal. Target: eight of ten attempts succeed unaided. Record conditions and anonymised feedback with transaction results. Use synthetic identity data in coursework evidence.

Task loads: L16, B20, D24, A20 hours, plus six event hours each. Dependencies: accepted bookings, delivery events and two iOS devices for sharing tests.

### 3 8 Risks dependencies and progress measures

These qualitative ratings are planning judgements. Owners review triggers during refinement and escalate unresolved dependencies at the review. Dates can change; safety criteria remain.

| Risk and rating | Trigger and response | Owner |
| --- | --- | --- |
| Identity access / High | Provider or data review delayed: escalate in Sprint 1; use synthetic fixtures and revise dates. | Diyar |
| Capacity conflicts / High | Concurrent conflict: prevent confirmation until reservation and overload tests pass. | Diyar |
| Map coverage / High | Directions fail: show unknown suitability and restrict the affected service corridor. | Bekassyl |
| Parcel contents / High | Declaration mismatch: refuse pickup, handle the report and preserve authorised evidence. | Dilnaz |
| Tracking / Medium | GPS denial or signal loss: label stale data and test recovery and stop controls. | Aizada |
| Availability / Medium | Individual overload: split tasks and reorder scope before promising new dates. | Aizada |

### Measures and acceptance evidence

Track completed stories, cycle time, blocked time and reopened defects. Re-estimate when evidence changes. DORA’s 2024 research highlights user focus and stable priorities [9]; these guide improvement rather than industry performance rankings.

Targets: one booking per seat under concurrent load, no cargo overload, no unauthorised identity or tracking access, and eight of ten observed tasks completed unaided. Report test conditions and sample sizes; five users provide formative feedback, not proof of market demand.

Example change: segment-based seat reuse adds occupancy intervals and cancellation cases. Keep it in the later backlog unless the team explicitly replaces scope and updates estimates.

## 4 Team Roles and Responsibilities

The following role allocation is our planning agreement. Product Owner and Scrum Master responsibilities do not create separate management layers. All four members contribute to producing and evaluating the Increment, and technical decisions remain visible to the team.

| Member and role | Responsibilities and collaboration |
| --- | --- |
| Dilnaz Kairkulova / Product Owner | Order the backlog, define outcomes and acceptance criteria, coordinate user research, and own consent and parcel-content wording. Support design and evidence review. |
| Bekassyl Zhaksylyk / Developer | Lead SwiftUI, graphical seats, addresses, MapKit routes and location integration. Pair with Diyar on API contracts and with Aizada on device behaviour. |
| Diyar Zholdubayev / Developer | Lead authentication, identity integration, transactions, data rules and audit controls. Document the data flow and review privacy-sensitive changes. |
| Aizada Sembayeva / Scrum Master and QA | Facilitate events, expose blockers and capacity limits, coordinate acceptance and accessibility tests, and maintain evidence throughout delivery. |

### Collaboration and decisions

Each issue names a delivery owner and a reviewer. A change is reviewed by someone other than its author. Bekassyl and Diyar agree request and response examples before UI and backend work diverge; Dilnaz and Aizada turn these examples into user scenarios. Testing remains a team responsibility rather than a final handoff to one person.

The Product Owner decides backlog order; Developers decide how much they can undertake and how to deliver it. The Scrum Master facilitates unresolved discussions. A blocker lasting one working day receives a named next action. Privacy and identity questions go to the relevant provider or qualified adviser before real personal data is processed.

Record decisions and affected acceptance criteria in the issue. Raise availability changes before Sprint Planning and share review evidence through the course process.

## 5 Tools and Techniques

We will keep planning close to implementation using GitHub Issues and Projects. Roadmap views support dates and milestones within the same project [10]. One board will use Backlog, Ready, In Progress, Review and Done, with a Blocked label. Each item records its story ID, priority, Sprint, owner, estimate and acceptance evidence.

| Tool or technique | Purpose and reason |
| --- | --- |
| GitHub Issues and Projects | A shared backlog and roadmap linked to code changes; avoids copying status between multiple trackers. |
| Git and GitHub Actions | Small reviewed changes and automated checks; preserve an auditable link between an issue, commit and test result. |
| Xcode and real iOS devices | Build SwiftUI flows, inspect seat layouts and validate permissions, keyboard behaviour and location updates. |
| Firebase Emulator Suite | Repeatable tests for application flows and access rules with synthetic records [11]. |
| Telegram and Google Meet | Short coordination messages and remote reviews; decisions are copied into the issue, not left only in chat. |
| Shared report and test log | Store meeting outcomes, anonymised feedback and acceptance evidence with clear version names. |

### Engineering and planning techniques

Planning poker uses 1, 2, 3, 5 and 8 points. Discuss disagreement to uncover missing information. Limit each person to one primary item in progress and clear review queues before adding work.

Use Swift domain tests, backend concurrency tests and security-rule tests; confirm maps and location behaviour on devices. App Check adds app attestation [12], complementing authentication and access rules.

Keep IINs, documents, contacts and exact addresses out of public issues and logs. Identity services, live SMS and distribution require explicit budget decisions; the effort estimate does not assume free services.

## 6 Reflection on Agile Values

The Agile Manifesto gives greater weight to people, working software, customer collaboration and adaptation while still recognising the value of processes, documentation, agreements and plans [13]. For Jol, these values will guide concrete choices during the four Sprints.

### Individuals and interactions

A confusing seat map is easier to resolve by showing it to a teammate than by exchanging long specifications. Bekassyl and Aizada will review the screen together, while Dilnaz checks whether a passenger understands front and rear positions. If Diyar is blocked by an identity provider, the team will clarify the dependency instead of treating a red board label as progress.

### Working software

Our review will show two people trying to reserve the same seat and a driver rejecting an overloaded parcel. A screenshot alone cannot establish those behaviours. We will retain concise notes explaining identity decisions, access rules and route limits because these notes help the next person understand and test the product.

### Customer collaboration

We will involve passengers, senders and drivers in the review scenarios. Their feedback will answer practical questions: can they identify their seat, understand a detour and recognise who can see an IIN verification result? We will not treat the loudest request as representative of every user; observed difficulties and differing needs will be recorded separately.

### Responding to change

Passenger seat booking and IIN-based accountability broaden the product beyond parcel matching. Their impact belongs in the backlog, estimates and privacy design. If a route fails or a verification dependency takes longer than expected, we will revise the forecast and explain the effect rather than remove an essential acceptance criterion.

### Anticipated challenges and learning

Timebox meetings to protect student capacity. Apply the Definition of Done despite feature pressure. IIN checks improve accountability but do not guarantee safe driving or lawful contents. Each retrospective selects one improvement, such as shorter review delays, and checks its effect in the next Sprint.

## 7 References

[1] Apple, “Meet MapKit for SwiftUI,” WWDC23, session 10043, 2023. [Online]. Available: https://developer.apple.com/videos/play/wwdc2023/10043/. Accessed: Oct. 23, 2026.

[2] Republic of Kazakhstan, “On Personal Data and their Protection,” Law No. 94-V, May 21, 2013, arts. 7, 8, 12 and 16, consolidated text. [Online]. Available: https://old.adilet.zan.kz/rus/docs/Z1300000094. Accessed: Oct. 23, 2026.

[3] Information Security Committee of Kazakhstan, “State service for control of access to personal data” [in Russian], Aug. 2, 2023. [Online]. Available: https://www.gov.kz/org/infsecurity/press/article/details/130936. Accessed: Oct. 23, 2026.

[4] K. Schwaber and J. Sutherland, The Scrum Guide. Nov. 2020. [Online]. Available: https://scrumguides.org/scrum-guide.html. Accessed: Oct. 23, 2026.

[5] Project Management Institute, The Future of Project Work: Moving Past Office-Centric Models, Pulse of the Profession 2024, Feb. 2024. [Online]. Available: https://www.pmi.org/learning/thought-leadership/future-of-project-work. Accessed: Oct. 23, 2026.

[6] M. Souppaya, K. Scarfone, and D. Dodson, “Secure Software Development Framework Version 1.1,” NIST SP 800-218, Feb. 2022, doi: 10.6028/NIST.SP.800-218. [Online]. Available: https://csrc.nist.gov/pubs/sp/800/218/final. Accessed: Oct. 23, 2026.

[7] World Wide Web Consortium, Web Content Accessibility Guidelines (WCAG) 2.2, W3C Recommendation, Dec. 12, 2024. [Online]. Available: https://www.w3.org/TR/2024/REC-WCAG22-20241212/. Accessed: Oct. 23, 2026.

### 7 References continued

[8] Apple, “What’s new in location authorization,” WWDC24, session 10212, 2024. [Online]. Available: https://developer.apple.com/videos/play/wwdc2024/10212/. Accessed: Oct. 23, 2026.

[9] D. DeBellis et al., DORA Accelerate State of DevOps 2024 Report. Google, 2024. [Online]. Available: https://research.google/pubs/dora-accelerate-state-of-devops-2024-report/. Accessed: Oct. 23, 2026.

[10] GitHub, “Roadmaps in Projects are now generally available,” GitHub Changelog, Mar. 23, 2023. [Online]. Available: https://github.blog/changelog/2023-03-23-roadmaps-in-projects-are-now-generally-available/. Accessed: Oct. 23, 2026.

[11] Google, “Introduction to Firebase Local Emulator Suite,” Firebase Documentation, n.d. [Online]. Available: https://firebase.google.com/docs/emulator-suite. Accessed: Oct. 23, 2026.

[12] T. Crowe, “What’s new from Firebase at Google I/O 2022,” Firebase Blog, May 11, 2022. [Online]. Available: https://firebase.blog/posts/2022/05/whats-new-at-google-io. Accessed: Oct. 23, 2026.

[13] K. Beck et al., “Manifesto for Agile Software Development,” 2001. [Online]. Available: https://agilemanifesto.org/. Accessed: Oct. 23, 2026.
