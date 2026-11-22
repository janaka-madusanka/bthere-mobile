# Assigned providers in Booking Details

GET /customers/me/bookings/{jobId}/providers supplies the booking-specific provider list. The client expects a jobId and providers envelope, with providerId, displayName, profilePhoto, averageRating, totalRatings, role, ratedByYou, and contact.callAllowed/unavailableReason. Phone is read from contact.phoneNumber (or provider.phoneNumber). This follows the backend developer's supplied summary; the full CUSTOMER_BOOKING_PROVIDERS_API.md was not present locally. Live response shape still needs manual verification.

The details page loads this separately from booking history. Errors offer Retry provider details and do not block booking information or financial actions. Team members retain backend ordering. No search-result profile is substituted for the assigned provider endpoint.

Only CONFIRMED/IN_PROGRESS plus contact.callAllowed=true expose the phone and dialler button. All other states hide the phone even if an old response allows calls. Opening the dialler requires an explicit tap; no automatic calls. Missing photos use a person icon. Account/epoch guards drop late reads. Status changes and foreground resume refresh details.
Provider rows now open a rounded scrollable Provider Details bottom sheet. Shows actual profile/rating/contact fields only. Experience, verification/background-check, About and Skills remain absent until a documented API supplies them. No sample/reference data is inserted.
