# Customer map filter ripple

The existing Hospital Care / service booking filter map uses a one-shot, 1.6-second ripple. Its three staggered, filled teal/cyan waves expand from the current search center and fade within the unchanged search boundary. The native Google Maps search circle remains in place. The visual reference is [Wave Lottie Animation](https://lottiefiles.com/free-animation/wave-lottie-animation-TYs5UbE3Ah); no Lottie asset or dependency is added.

## Structure

- `app/widgets/search_range_ripple.dart`: reusable `SearchRangeRipple` widget owns its animation controller, one-shot timing, rapid restart, deferred playback and reduced motion. Its `SearchRangeRipplePainter` draws overlapping translucent cyan discs. It accepts only a change token, projected geometry and a paused flag, with no Google Maps, Riverpod or provider API dependency. It never guesses a map center.
- `booking_location_picker.dart`: supplies geographic projection and camera readiness. Completing a programmatic camera move releases pending playback even if Google Maps does not emit another idle callback. Later filter changes therefore work at manually selected locations too. All editable location-picker maps use the component; read-only views do not start animations on entry. Screen-coordinate reads remain throttled during gestures and never run on animation frames.
- `customer_booking_map.dart`: forwards camera movement/idle callbacks while preserving the existing map widget/platform-view lifecycle.
- `booking_details_canvas.dart`: passes the existing booking draft's filter signature, including destination coordinates. Provider result updates do not participate in this signature.

Automatic camera refitting on provider-result changes and panel height changes was removed. Initial positioning, location changes and the explicit recenter action still use the existing camera behavior. The current 10 km search default and provider request construction are unchanged by this refinement.

## Validation

`booking_map_ripple_test.dart` covers no startup pulse, 1.6-second progress, rapid restart, unchanged radius, retained map element, no per-frame native projection calls, stable camera during provider/panel updates, pan/zoom reprojection, playback after location-camera completion even without an idle event, reduced motion and safe disposal during pending projection.

Existing booking widget regressions and Google Maps marker/location checks also run. The older map test expectation was updated to the already-requested 10 km default. `tool/water_ripple_preview_test.dart` renders a synthetic map preview; a native phone review remains useful for device-specific rendering and gesture alignment.

Visual refinement: the public reference preview and motion data were inspected directly. The painter now uses flat transparent filled discs with linear growth and fading opacity, matching that reference style. White highlights, shaded troughs and outlined wave crests were removed. The public animation is a visual reference only; its asset is not bundled.

## Reuse

Place `SearchRangeRipple` in a `Positioned.fill` above the relevant map. Change `trigger` only when a meaningful filter or location changes. Supply `center`, `radius` and optional projected `east`/`north` vectors in logical pixels. While camera movement or projection is pending, use `paused: true` or null geometry. The component queues the latest trigger and plays when ready. Set `trigger: null` to disable playback. Do not derive the token from provider-result or loading-state notifications.

Extraction validation: 59 component, booking and map widget tests passed; whole customer-app analysis was clean. The component is shared through the existing location picker, rather than adding decorative animation to unrelated screens.
`nLatest visibility refinement: replaced faint flat cyan discs with soft radial teal fills and a defined 2px teal crest. This supersedes the earlier no-outline visual note above. Three staggered waves, 1.6-second one-shot timing, geographic clipping/projection, camera behavior and reduced-motion handling remain unchanged. The goal is readable wave edges on roads and terrain while keeping map labels visible.
Timing update: slowed the default ripple cycle from 1.6 seconds to 2.8 seconds per user feedback. Staggered emissions, one-shot playback and trigger behavior remain unchanged. Seven component/map regressions passed; analysis clean.
Current playback update: editable maps now opt into repeating 2.8-second waves with a 1.4-second idle gap. The component stops its ticker during the gap and pauses/cancels its gap timer during camera gestures, background/inactive lifecycle, covered routes, disabled ticker visibility or missing projection. It resumes when eligible. Reduced motion suppresses playback; read-only maps do not opt into repeat. No extra native projection or network calls are made per cycle. This supersedes earlier one-shot-only notes; reusable component default remains one-shot.
