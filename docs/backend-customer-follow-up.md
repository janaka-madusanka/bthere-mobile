# Backend devට යවන්න message එක

Customer app එකේ අලුත් doc එකට අනුව Book now / option notice validation,
paid cancellation preview + confirm, wallet refund receipt, provider cancellation
compensation සහ Google Maps navigation link implement කරලා තියෙනවා.
කලින් payment retry, START code, completion, ratings/reviews, customer tracking
map සහ notification integration එකත් තියෙනවා. දැන් real environment එකේ test
කරන්න මේ දේවල් අවශ්‍යයි:

1. **Deployment සහ data setup**
   Testing API එකේ අලුත් endpoints/DB migrations deploy/run කරලාද confirm කරන්න.
   Instant-enabled Ride option එකේ සහ scheduled Hospital Care option එකේ actual
   `minimumNoticeMinutes`, `instantBooking`, tracking mode සහ refund policy
   configuration දෙන්න. New doc එකේ තවම “implemented locally; not deployed”
   කියලා තියෙන නිසා deployment version/commit එකත් දෙන්න.

2. **Book now payment retry rule එක පැහැදිලි කරන්න**
   Book now එකේ start time එක provider acceptedAt වෙනවා කියලා අලුත් doc එකේ
   තියෙනවා. කලින් retry rule එක confirmation deadline එක service start time
   පහු නොකරන බව කියනවා. Acceptance + 2-minute initial payment window සහ පළමු
   failure එකෙන් ලැබෙන retry window එක instant bookings වලට කොහොමද apply වෙන්නේ?
   Instant booking එකක acceptance response සහ පළමු/දෙවන wallet/card failure
   පස්සේ `/payment-window` response examples දෙන්න (`confirmationExpiresAt`,
   `paymentRetryStartedAt`, `paymentDeadlineLimit`, canPay/canCancel ඇතුළුව).
   Customer frontend එක deadline ගණනය කරන්නේ නැහැ; server value එකම ගන්නවා.

3. **Firebase client configuration / live sending**
   Android package සහ iOS Runner bundle ID දෙකම `com.bthere.customer`.
   මේ app එකට ගැළපෙන `google-services.json` සහ `GoogleService-Info.plist` files
   දෙන්න. Backend FCM sender එක same Firebase project එකට configure කරලාද,
   testing environment එකේ sending enable ද, iOS APNs setup කරලාද confirm කරන්න.
   Firebase Admin service-account private key mobile app එකට අවශ්‍ය නැහැ.
   Current `/me/booking-devices` contract එකේ FCM registration token එකම app
   එකෙන් යවනවා; FID payload එකකට backend contract වෙනස් කරලා නම් කියන්න.

4. **Provider app tracking write contract**
   Customer doc එකේ tracking GET තියෙනවා. Provider app එකට Start journey,
   Arrived, GPS/location upload සහ end/stop-sharing සඳහා actual routes,
   request/response examples සහ allowed states දෙන්න. GPS update interval,
   timestamp/heading/accuracy rules සහ TO_CUSTOMER/FULL_TRIP behavior පැහැදිලි
   කරන්න. Customer app එක provider location upload කරන්නේ නැහැ; ඒ producer එක
   Provider app එකට වෙනම implement කරන්න ඕන.

5. **Tracking disabled වූ booking එකේ assigned provider details**
   Tracking response නැති/NOT_SUPPORTED booking එකකට සහ app restart එකකට පස්සේ
   name/photo/rating ලබාගන්න owned booking provider-details endpoint එකක් තියෙනවා
   නම් contract එක දෙන්න. නැත්නම් single/team providers සඳහා ඒ read endpoint එක
   implement කරලා දෙන්න. Customer-owned booking access සහ history/cancelled
   states cover කරන්න. Contact phone/email අලුතින් ඉල්ලන්නේ නැහැ.

6. **Compensation settlement updates**
   `customerPaidAmount` පස්සේ වැඩි වුණාම ඒ wallet credit එකට customerට ලැබෙන
   event/push type එකක් තිබේද කියන්න. දැනට app එක saved receipt GET කරලා actual
   paid amount පෙන්වනවා; Check compensation එකෙන් නැවත කියවන්න පුළුවන්.
   Cancellation refund credit එකේ exact wallet ledger operation type එක සහ
   response sample එකත් දෙන්න; doc එකේ `PROVIDER_PENALTY` නම පමණක් explicit.

Optional recovery improvement: active own booking-requests list endpoint එක සහ
bookings response එකේ `requestId` දාන්න කලින් යෝජනාව implement කළා නම් contract
එක දෙන්න. දැනට app එක local references + owned booking-events paging භාවිත කරනවා.
Service start පස්සේ disputes/cancellation හෝ explicit START-code lock state
අලුතින් support කරනවා නම් ඒවාටත් වෙනම confirmed contract අවශ්‍යයි; දැනට ඒ
business actions frontend එකෙන් invent කරලා නැහැ.
