# Project instructions

## GitHub and delivery

- The user explicitly requests committing and pushing every completed change to this project.
- Repository: `bekasyl00/application`. Default branch: `main`.
- At the end of each coherent change, run appropriate checks, inspect the diff, create a descriptive commit and push to the existing upstream. Do not leave completed changes uncommitted or unpushed.
- Do not commit transient intermediate edits, dependency directories, generated build products, Firebase client configuration, signing keys or service account credentials. Respect `.gitignore` and inspect staged files.
- Never force-push, discard user changes, rewrite published history or change repository visibility without explicit authorization.
- If GitHub authentication, network access or a check prevents publication, preserve the work and report the exact blocker. Do not claim a successful push or deployment without confirming it.
- GitHub Actions validates the Swift core, iOS simulator build and Firebase rules. A push uploads source code; Firebase deployment and App Store distribution are separate operations requiring configured accounts.

## Implementation

- iOS 17+ SwiftUI. Shared domain models live in `Sources/ParcelCore` and are included directly in the Xcode app target.
- Use the applicable ECC Swift persistence and security review patterns for changes to persistence, authorization and user data.
- Keep exact addresses, recipient data and participant contact details out of public marketplace documents.
- Orders mutate through Firebase callable Functions; acceptance and status changes must remain transactional.
- Local demo state is isolated from real Firebase accounts.
- If source files are added, run `python3 scripts/generate-project.py`; this regenerates the project and can replace local signing settings.
- Validate core changes with `bash scripts/test-core.sh` and `swift test` when Xcode is available. Validate backend/security changes with `npm test` and `npm run test:rules`.
