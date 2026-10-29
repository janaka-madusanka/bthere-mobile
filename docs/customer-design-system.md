# Customer design system — 26 October 2026

Source: supplied `Bthere_Mobile_App_Typography_and_Color_Guidelines.docx`. Applies to Customer app only; shared package and Provider app remain unchanged because Provider is maintained separately.

`apps/customer_app/lib/app/customer_theme.dart` defines the Customer palette and typography roles. Root app and nested auth, verification, profile, discovery and booking themes all use it. Shared buttons and fields inherit this theme; no API contracts, routing or booking behavior changed. Existing logo/SVG artwork retains original aspect ratio and colors.

## Typography

Public Sans is bundled locally with 400, 500, 600 and 700 weight declarations; no runtime font service is used. Source: [Google Fonts Public Sans](https://github.com/google/fonts/tree/main/ofl/publicsans), with OFL license stored beside the font. Existing brand artwork keeps its own lettering.

| Role | Size / line height | Weight |
| --- | --- | --- |
| Screen title | 24 / 32 | 700 |
| Section | 18 / 24 | 600 |
| Card title / button | 14 / 20 | 600 |
| Body | 14 / 20 | 400 |
| Form values | 12–14 | 500 |
| Compact / labels | 12 / 16 | 500 |
| Micro | 10 / 12 | 500 |
| Absolute minimum, rare tertiary only | 8 / 10 | 500 |

Controls retain accessible scaling and scrolling for narrow screens, keyboard and large-text modes. Essential text is not reduced to 8 px. CTA height is 50, button radius 12 and default input radius 10. Cards use restrained neutral borders and white surfaces. Primary action, informational and disabled control states come from the Customer theme.

## Palette

Brand primary #0F666B; action #008F95; secondary #3E8EC7; care green #62C3A0; mint #66F4F2; coral #F2998C. Background #F8FAFB; surface #FFFFFF; selection #E5FAFA; border #E6EDF0. Primary text #0B3037; secondary #687B83; hints #8997A0. Success #21866D; warning #B7791F; error #C44444. Existing illustration gradients remain artwork; remote service/marker assets are not recolored.

Public Sans is loaded in Customer widget tests and render tools. Regression checks cover designer role values and the actual inherited font/button size of shared controls, as well as Provider theme isolation. Existing large-text, small-device and booking tests remain part of verification.

Verification: 185 Customer tests passed; Customer analysis clean; 59-file formatting check passed; Customer debug APK built. Auth and booking preview suites passed using Public Sans. Shared design-system and Provider sources were not modified. Workspace analysis additionally retains the existing Provider withOpacity deprecation, which is outside this Customer-only change.

