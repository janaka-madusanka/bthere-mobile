# Service-specific customer documents

## Booking entry

Before a request is created, requirements/eligibility determine whether a blocking upload requirement is missing, pending, rejected or expired. Such a service opens Service documents instead of filters/provider search. This is generic by service/option IDs; Home Care is not hardcoded. Approved/provided documents do not bypass remaining backend eligibility rules.

The document form uses scoped GET requirements metadata, existing private file upload/view and explicit requirementId submission. Configured file counts/types/size are shown and validated. Under-review documents are read-only; rejected/expired evidence can be replaced. Expiry remains optional unless the backend requires it: no certificate lifespan is invented.

Closing or submitting reloads requirements and eligibility. Acknowledged external document saves clear only that requirement's stale draft. Pending remains blocked. After approval, Check review status returns to booking filters; if context was previously denied, it reloads the booking context first. Failures retain retry and never enable search. Context-denied loads retain independently readable document metadata.

## Profile

My documents includes Add service documents. The customer chooses an active-market service and option, including those with restricted access, then reads scoped requirements. This exposes unsubmitted option documents that profile-overview intentionally omits. Existing document status and private files are reused, not duplicated by submission ID. The overview is refreshed on return.

## Validation and manual review

- Full customer suite492 passes; new tests cover missing gate before search, explicit rejected resubmission, pending read-only, approval return, scoped first-submission discovery from Profile, enlarged text and denied context.
- Manual test with an authorized test account: Home Care should show CUSTOMER_HOME_CARE_GN and configured 1-2 files/10 MB rules; Hospital Care should not inherit that requirement. No live certificate upload/approval is performed by the assistant.
- User submits a permitted test certificate, verifies pending/search blocked, then asks an authorized admin to review. Reject should expose reason/resubmit; approve should permit booking only when backend eligibility becomes true.
