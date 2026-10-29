import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'customer_brand_image.dart';

/// Shared visual treatment for Customer email and SMS verification.
class CustomerVerificationPage extends StatelessWidget {
  const CustomerVerificationPage({
    super.key,
    required this.formKey,
    required this.otp,
    required this.phone,
    required this.destination,
    required this.remaining,
    required this.busy,
    required this.error,
    required this.onSubmit,
    required this.onResend,
    required this.onChangeDestination,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController otp;
  final bool phone, busy;
  final String destination;
  final int remaining;
  final String? error;
  final VoidCallback onSubmit, onResend, onChangeDestination;

  @override
  Widget build(BuildContext context) {
    final base = CustomerTheme.authentication();
    const navy = Color(0xFF0B3037),
        muted = Color(0xFF687B83),
        teal = Color(0xFF008F95);
    final seconds = remaining.clamp(0, 86400);
    final countdown =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Theme(
      data: base,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        body: BThereBrandedBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final top = ((bounds.maxHeight - 650) * .5).clamp(40.0, 112.0);
                return SingleChildScrollView(
                  key: const ValueKey('customer-verification-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(24, top, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: BThereBrandImage(
                                asset: BThereBrandAsset.carePromise,
                                width: 180,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Semantics(
                              header: true,
                              child: Text(
                                phone
                                    ? 'Verify your phone'
                                    : 'Verify your email',
                                textAlign: TextAlign.center,
                                style: base.textTheme.headlineMedium?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'We’ve sent a 6-digit verification code to',
                              textAlign: TextAlign.center,
                              style: base.textTheme.bodyLarge?.copyWith(
                                fontSize: 14,
                                color: muted,
                                height: 1.4,
                              ),
                            ),
                            Text(
                              destination,
                              textAlign: TextAlign.center,
                              style: base.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                color: navy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 28),
                            CustomerOtpInput(
                              controller: otp,
                              enabled: !busy,
                              onSubmit: onSubmit,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              phone
                                  ? 'Enter the 6-digit code sent to your phone.'
                                  : 'Enter the 6-digit code sent to your email.',
                              textAlign: TextAlign.center,
                              style: base.textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF9FA),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      phone
                                          ? Icons.sms_outlined
                                          : Icons.mail_outline,
                                      color: teal,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          phone
                                              ? 'Can’t find the SMS?'
                                              : 'Can’t find the email?',
                                          style: base.textTheme.titleMedium
                                              ?.copyWith(
                                                color: navy,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          phone
                                              ? 'Check your messages and mobile signal.'
                                              : 'Check your spam or junk folder.',
                                          style: base.textTheme.bodyMedium
                                              ?.copyWith(color: muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Didn’t receive the code?',
                                  style: base.textTheme.bodyMedium?.copyWith(
                                    color: muted,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  key: const ValueKey('customer-otp-resend'),
                                  onPressed: busy || remaining > 0
                                      ? null
                                      : onResend,
                                  style: TextButton.styleFrom(
                                    disabledForegroundColor: teal,
                                    foregroundColor: teal,
                                    textStyle: base.textTheme.labelLarge
                                        ?.copyWith(fontSize: 14),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    remaining > 0
                                        ? 'Resend code ($countdown)'
                                        : 'Resend code',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (error != null) ...[
                              BThereInlineError(error!),
                              const SizedBox(height: 16),
                            ],
                            BTherePrimaryButton(
                              key: const ValueKey('customer-auth-submit'),
                              label: 'Verify and continue',
                              loading: busy,
                              onPressed: busy ? null : onSubmit,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              key: const ValueKey(
                                'customer-otp-change-destination',
                              ),
                              onPressed: busy ? null : onChangeDestination,
                              child: Text(
                                phone
                                    ? 'Use a different phone number'
                                    : 'Use a different email address',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One editable input preserves paste, autofill, backspace and leading zeroes;
/// six decorative slots reflect the same controller without six competing fields.
class CustomerOtpInput extends StatefulWidget {
  const CustomerOtpInput({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;
  @override
  State<CustomerOtpInput> createState() => _CustomerOtpInputState();
}

class _CustomerOtpInputState extends State<CustomerOtpInput> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
    validator: (_) => RegExp(r'^\d{6}$').hasMatch(widget.controller.text)
        ? null
        : 'Enter the six-digit code.',
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([widget.controller, _focus]),
          builder: (context, _) => SizedBox(
            height: MediaQuery.textScalerOf(context)
                .scale(24)
                .clamp(58.0, 96.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              key: ValueKey('customer-otp-slot-$i'),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xCCFFFFFF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      _focus.hasFocus &&
                                          i ==
                                              widget.controller.text.length
                                                  .clamp(0, 5)
                                      ? const Color(0xFF00A8BA)
                                      : const Color(0xFFDCE4F1),
                                  width: 1.3,
                                ),
                              ),
                              child: Text(
                                i < widget.controller.text.length
                                    ? widget.controller.text[i]
                                    : '',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0B3037),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    alwaysIncludeSemantics: true,
                    child: TextField(
                      key: const ValueKey('customer-otp'),
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Six-digit verification code',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: field.didChange,
                      onSubmitted: (_) => widget.onSubmit(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (field.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}
