# Profile API contracts needed

The UI uses Figma `246:3465` (collapsed) and `254:4284` (expanded). The supplied
**Complete Provider Registration and Service Approval API Flow (1).pdf** is the
reference for existing APIs. The user confirmed that skills, languages, and working
hours must be **global provider settings**, not selected-service settings.

## Already supported by the supplied document

| Profile area | Existing source / action |
| --- | --- |
| Name, birth date, gender, bio, photo URL, verification | GET and PUT `/providers/me/profile` |
| Rating and review count | `averageRating`, `totalRatings` in the profile response |
| Registered service count | GET `/providers/me/service-types` |
| Email and phone | Existing authenticated session user metadata, when returned |
| Uploaded documents and review/expiry status | GET `/providers/me/documents` |
| Applicable document requirements | Requirements for registered services, filtered by active selected options and merged by document type |
| Upload / register a document | Existing document editor, POST `/uploads/documents`, POST `/providers/me/documents` |
| Image document preview | GET `/uploads/view-url?key=...` |
| Available for Work toggle | Existing full profile PUT with all documented editable fields preserved |
| Sign out | Existing logout and secure-session clearing controller |

## Required to finish live integration

Please provide the actual endpoint paths, request/response examples, enum values,
validation rules, and error responses for these capabilities. The names below are
**proposals for backend review**, not endpoints the app currently calls.

1. **Global skills and languages:** read/save selected skill IDs and language codes;
   read the global skill catalog (`skillId`, `name`, required/approval rules if any).
   The document only defines `/providers/me/services/{assignmentId}/skills` and
   `/languages`. Those cannot implement a global profile update. Please define
   whether global values replace service values or become inherited defaults.
2. **Global weekly availability:** read/save `availableAnyDay`, `availableAnyTime`,
   and `weeklySlots` (`dayOfWeek`, `startTime`, `endTime`). Specify timezone, multiple
   slots per day, closed-all-week behavior, and how this affects service schedules.
   The documented endpoint is assignment scoped and is not used for global edits.
3. **Completed bookings:** a provider-wide completed-booking count, including the
   statuses counted. A missing/error response must be distinguishable from zero.
4. **Payout/bank details:** read/create/update payment method, bank ID/name,
   account holder name and account number; bank/method catalogs and validation.
   Prefer masked account numbers in reads. The editor never submits an unchanged
   mask as an account number. Provide verification state and permissions if needed.
5. **Personal address:** provider city and country for the `Colombo, Sri Lanka`
   slot, plus the update contract. `marketId` is a business market and is not a
   personal residential address.
6. **Profile photo upload:** accepted file types/size, upload endpoint and response,
   and whether PUT profile expects a durable URL or storage key. The existing PUT
   accepts `profilePhoto`, but the document only specifies a document-file upload.
7. **Email/phone changes:** authenticated contact read/update plus verification and
   uniqueness rules. Existing session values can be displayed, but the profile PUT
   does not document changing them.
8. **Document deadlines (only for the exact countdown copy):** a per-document
   `dueAt`/grace-period contract and what starts the countdown. `createdAt` and
   `expiryDate` do not establish "upload within 7 days" or "5 days left". Current UI
   shows actual upload/expiry dates and Missing/Reviewing/Verified/Rejected/Expired.
9. **Support and security destinations:** help/FAQ/contact URL or API and the
   intended privacy/security actions (policy URL, password change, account deletion,
   etc.). Current cards provide local guidance and the working sign-out action.

## Suggested aggregate read shape

A single authenticated overview response could reduce round trips. This is a
proposal; the app can also adapt separate documented endpoints.

```json
{
  "completedBookings": 24,
  "city": "Colombo",
  "country": "Sri Lanka",
  "skills": [{"skillId": 10, "name": "Personal Care"}],
  "skillCatalog": [{"skillId": 10, "name": "Personal Care"}],
  "languages": ["ENGLISH", "SINHALA"],
  "availability": {
    "availableAnyDay": false,
    "availableAnyTime": false,
    "weeklySlots": [
      {"dayOfWeek": "MONDAY", "startTime": "08:00:00", "endTime": "17:00:00"}
    ]
  },
  "payout": {
    "paymentMethod": "BANK_TRANSFER",
    "bankId": 1,
    "bankName": "Example Bank",
    "accountHolderName": "Example Provider",
    "maskedAccountNumber": "****9012"
  }
}
```

Global writes should accept skill ID/language arrays, the weekly availability
object, and payout details as independent updates. Please confirm replacement
semantics and successful response status/body before the HTTP adapter is added.

## Current integration boundary

`ProfileSupplementRepository` defines typed load/save operations for the global
panels. Its production default returns `PROFILE_CONTRACT_REQUIRED` and makes no
HTTP calls. Test-only fixtures supply complete global data to verify the UI and
save/retry behavior. No synthetic values are used in the production screen.
