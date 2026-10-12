import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../application/email_verification_controller.dart';
import '../widgets/auth_page.dart';
import '../widgets/auth_brand_header.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});
  final String email;
  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _form = GlobalKey<FormState>();
  final _otp = TextEditingController();
  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  void _submit() {
    if (ref.read(emailVerificationControllerProvider).loading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    ref
        .read(emailVerificationControllerProvider.notifier)
        .submit(email: widget.email, otp: _otp.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailVerificationControllerProvider);
    return AuthPage(
      backRoute: AppRoutes.emailRegistration,
      busy: state.loading,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader(
              title: 'Verify your email',
              subtitle: 'We sent a verification code to',
            ),
            const SizedBox(height: BThereSpacing.xs),
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: BThereSpacing.xl),
            BThereTextField(
              label: 'Verification code',
              labelPlacement: BThereFieldLabelPlacement.above,
              hint: 'Enter your code',
              textAlign: TextAlign.center,
              textStyle: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(letterSpacing: 4),
              controller: _otp,
              enabled: !state.loading,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter your verification code.'
                  : null,
            ),
            if (state.failure != null) ...[
              const SizedBox(height: BThereSpacing.md),
              AuthFailureMessage(state.failure!.message),
            ],
            const SizedBox(height: BThereSpacing.lg),
            BThereButton(
              label: 'Verify email',
              onPressed: _submit,
              loading: state.loading,
              fullWidth: true,
              trailingIcon: const Icon(
                Icons.arrow_forward,
                size: BThereSpacing.lg,
              ),
            ),
            const SizedBox(height: BThereSpacing.xs),
            TextButton(
              onPressed: state.loading
                  ? null
                  : () => context.go(AppRoutes.emailRegistration),
              child: const Text('Change email'),
            ),
          ],
        ),
      ),
    );
  }
}
