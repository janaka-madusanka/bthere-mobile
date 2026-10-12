# Authentication branding

The supplied SVGs are bundled at these paths:

- `assets/branding/bthere_logo_care_promise.svg`
- `assets/branding/google_logo.svg`
- `assets/branding/apple_logo.svg`

These files are byte-identical copies of the supplied exports in `branding/`.
The Care Promise mark is used on email sign-in, registration and verification.
Sign-in and registration display the supplied Google and Apple marks in disabled
social buttons. The dormant Google implementation also retains the supplied
Google mark; no social sign-in action is activated.

Their viewBox ratios are 155:77 for Care Promise and 25:29 for both social marks.
`AuthBrandImage` uses proportional dimensions and BoxFit.contain, with no color
filter or tint. The supplied exports contain clipped, embedded PNG artwork in
objectBoundingBox patterns. `AuthBrandAssetLoader` expands only this pattern
wrapper into equivalent translate/scale groups at load time, retaining the
original embedded bytes, use transform, clipPath and viewBox. Source SVGs are
unchanged. This makes the supplied exports render reliably through flutter_svg
without recoloring, cropping or stretching the visible artwork.

The previous `google_g.png` remains on disk for historical provenance but is no
longer bundled or referenced by the auth UI. Its original source was
https://developers.google.com/static/identity/images/g-logo.png; usage guidance:
https://developers.google.com/identity/branding-guidelines.
