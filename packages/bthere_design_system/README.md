# B there Design System

Shared Flutter visual foundations for Customer and Provider. Import only
`package:bthere_design_system/bthere_design_system.dart`; do not import `src/`.
This package depends only on Flutter, with no state management, routing,
networking, session, authentication, or role-specific content.

Use `BThereTheme.light()` / `BThereTheme.dark()` on MaterialApp and consume
`Theme.of(context).colorScheme` and `textTheme` for semantic light/dark roles.
Use shared tokens instead of duplicating feature colors, spacing, or radii.

Approved palette (`BThereColors`): primary #0F666B, secondary #3E8EC7,
green #62C3A0, soft mint #66F4F2, coral #F2998C, background #F8FAFB,
text primary #0F2E33, secondary #667D8C, tertiary #8FA1A8, surface #FFFFFF,
border #D7E1E5, divider #E6EEF0, error #D95C5C, disabled background #E4EAEC,
text #8FA1A8, and border #CDD9DD. Accessible text/error/input-outline role
variants preserve those palette tokens. Dark roles are selected explicitly,
with a lighter teal foreground and the original primary as its container.

`BThereSpacing`: xxs 4, xs 8, sm 12, md 16, lg 24, xl 32, xxl 40, xxxl 48;
an 8px base rhythm with compact half steps. `BThereRadius`: control 16,
surface 24.

`BThereTypography`: Nunito; h1 28/700, h2 24/700, h3 20/600,
bodyLarge 16/500, body 16/400, label 14/600, caption 12/400,
button 16/700. **Verified local Nunito assets are pending.** Flutter uses
platform fallback today; no unverified assets or runtime fetching are included.
Text scaling is preserved. Font delivery/licensing must be verified before
bundling final local assets.

`BThereButton` provides primary/outlined variants, label, nullable callback,
loading, enabled, leadingIcon, trailingIcon, and fullWidth. Loading disables interaction and
retains the label. Controls have a minimum 56px height and can grow with text.
Full width requires bounded horizontal constraints.

`BThereTextField` wraps TextFormField with label/hint, controller, keyboardType,
obscureText, enabled, validator/errorText, prefix/suffix icon slots,
textInputAction, autofillHints, callbacks, focusNode, and autovalidateMode.
Optional above-field labels retain editable-field semantics. helperText,
textAlign, and textStyle support generic form/code-input presentation; floating
labels remain the default. Filled actions have a subtle theme-owned shadow.
Callers own validation, controllers, password visibility, and localized copy.
Optional autocorrect/enableSuggestions overrides keep secure entry protected
when text is revealed. Interactive suffix widgets should supply accessible
tooltips/labels.

`BThereLoadingIndicator` accepts size/color/semanticsLabel. `BThereStateView`
accepts title, optional message, and optional action widget. Callers own page
scrolling; Provider screens use SafeArea and SingleChildScrollView.

Themes use Material 3 and configure scaffold, color scheme, text, cards, inputs,
filled/outlined/text buttons, dividers, progress, and snackbars. Provider follows
system theme mode. Customer integration, logos, and theme preferences remain
separate tasks. Provider email UI lives in the app, outside this package.
