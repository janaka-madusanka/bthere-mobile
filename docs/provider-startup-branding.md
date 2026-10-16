# Provider startup branding

The startup page uses the original bundled Care Promise logo on a light mint background, with a gentle pulse and an indeterminate loading indicator. Reduced-motion settings stop the pulse. Existing session restoration, account checks, failures and retry behavior control navigation; no artificial delay is added.

Android launcher assets include legacy density icons and an adaptive icon. Android native launch resources support light appearance in both device themes, including Android 12+. iOS AppIcon sizes and LaunchImage variants use the same original artwork.

Regenerate assets from `apps/provider_app`:

```powershell
flutter test --no-pub tool/generate_brand_assets.dart
```

A full rebuild/install is required to see native icon and splash changes; hot reload updates only Flutter UI. iOS launch resources require validation on macOS/iOS.
