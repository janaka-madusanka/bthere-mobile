# Customer development integration validation ? 22 November 2026

This branch combines the seven commits from PR #6 with the current Customer booking/profile work, Provider chat integration and helper/UI-lab tooling. Base: origin/development at e0ac99d. Original working files were preserved in the main worktree; only selected source files were copied to this clean review branch.

## Fresh checks on the review branch

| Check | Result |
| --- | --- |
| Customer full suite | 573 passed |
| Provider full suite | 790 passed, 40 failed |
| Provider development comparison | 779 passed, the exact same 40 test names failed |
| Shared design-system suite | 24 passed |
| Provider acceptance helper | 30 passed, including Windows encrypted credential roundtrip |
| Customer and Provider analysis | No issues found |
| Proposed file scan | 256 files checked before final validation docs; no private key/token findings or unwanted paths |

Provider failures include existing golden/visual, registration/document expectations and startup timing tests. No new failing test names were introduced. The development baseline could not resolve dependencies as checked out because Customer pubspec.yaml contains duplicate dependency/font YAML keys. For the isolated comparison only, that Customer manifest was replaced with the valid reviewed Customer manifest; Provider production/test sources were unchanged. This is not a claim that untouched development is green or directly runnable.

The full Provider test failure-name list is below. Tests use fake services; no live booking/payment/chat message or receipt was created.

- catalog routes pending applications to the new page
- pending application matches the status design
- catalog routes rejected applications to the new page
- rejected application matches the status design
- file size and types match the reference
- account check shows loading and retry requests coalesce
- session reread failure after verification displays safe restoration failure
- Google repository success with failed local session never reaches Home
- completion 401 remains an error, retry recovers without missing-profile inference
- completion 404 remains an error, retry recovers without missing-profile inference
- completion 500 remains an error, retry recovers without missing-profile inference
- login awaits persistence then refreshes session on same router and reaches services
- completion offline remains an error, retry recovers without missing-profile inference
- completion timeout remains an error, retry recovers without missing-profile inference
- completion malformed remains an error, retry recovers without missing-profile inference
- success with failed local session cannot enter services
- registration retry retains key metadata and does not re-upload
- registration expiry contract false
- duplicate submit blocked during pending registration
- upload failure leaves draft and no registration, retry uploads
- successful registration refresh failure cannot resubmit same draft
- service-scoped route back and backend completion refresh preserves selections
- Services Figma reference registered=false
- registered service opens overview at text scale 1.0
- Services Figma reference registered=true
- registered service opens overview at text scale 1.5
- Figma layout reference new
- Figma layout reference registered
- profile visual preview uses the production navigation shell
- Opportunities opens a selected temporary tab with no backend reads
- Messages opens a selected temporary tab with no backend reads
- picker uses themed layout and supports large text
- coverage uses themed layout and supports large text
- caregiving overview new
- caregiving overview registered
- wallet reference layout with server-backed test data
- narrow large-text failure placeholder stays scrollable
- checking shows startup then auth without recreating router
- missing config shows explicit failure rather than infinite spinner
- storage failure displays safe startup failure without redirect loop

## Scope boundaries

Local *.local.json configuration, credentials, temporary PDF tooling, caches, APKs and generated test failure images are excluded. The debug UI lab uses a separate entrypoint and Android identity, with fake booking data and no live API configuration.

Chat has server-acknowledged Sent and Seen indicators; Delivered/attachments and explicit availability/error metadata remain backend follow-up work. Push gateway integration exists but real background/cold-start delivery and iOS native validation remain manual/external checks. This PR does not claim those are complete.

Latest full test logs are local ignored build/pr-review-customer-tests.jsonl, build/pr-review-provider-tests.jsonl and build/pr-baseline-provider-tests.jsonl. Analyses are build/pr-review-customer-analysis.log and build/pr-review-provider-analysis.log.
