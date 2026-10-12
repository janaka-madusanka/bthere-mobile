import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../application/email_registration_controller.dart';
import '../application/email_verification_controller.dart';
import '../widgets/auth_page.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_support_controls.dart';

class EmailRegistrationScreen extends ConsumerStatefulWidget {
  const EmailRegistrationScreen({super.key});
  @override
  ConsumerState<EmailRegistrationScreen> createState() =>
      _EmailRegistrationScreenState();
}

class _EmailRegistrationScreenState
    extends ConsumerState<EmailRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _agreed = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(emailRegistrationControllerProvider).loading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final account = await ref
        .read(emailRegistrationControllerProvider.notifier)
        .submit(email: email, password: _password.text);
    if (!mounted || account == null) return;
    _password.clear();
    _confirm.clear();
    context.go(
      AppRoutes.emailVerification,
      extra: EmailVerificationContext(email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailRegistrationControllerProvider);
    return AuthPage(
      signingIn: false,
      busy: state.loading,
      child: Form(
        key: _form,
        child: AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BThereTextField(
                label: 'Email address',
                labelPlacement: BThereFieldLabelPlacement.above,
                prefix: const Icon(Icons.mail_outline),
                hint: 'you@example.com',
                controller: _email,
                enabled: !state.loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Enter your email.';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                    return 'Enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: BThereSpacing.md),
              BThereTextField(
                label: 'Password',
                labelPlacement: BThereFieldLabelPlacement.above,
                hint: 'Create a secure password',
                prefix: const Icon(Icons.lock_outline),
                helperText: 'Use 10–72 characters.',
                controller: _password,
                enabled: !state.loading,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                suffix: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: state.loading
                      ? null
                      : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                validator: (value) {
                  final length = (value ?? '').runes.length;
                  if (length == 0) return 'Enter a password.';
                  if (length < 10 || length > 72) {
                    return 'Use 10–72 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: BThereSpacing.md),
              BThereTextField(
                label: 'Confirm password',
                labelPlacement: BThereFieldLabelPlacement.above,
                hint: 'Confirm your password',
                prefix: const Icon(Icons.lock_outline),
                controller: _confirm,
                enabled: !state.loading,
                obscureText: !_showConfirm,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _showConfirm
                      ? 'Hide confirm password'
                      : 'Show confirm password',
                  onPressed: state.loading
                      ? null
                      : () => setState(() => _showConfirm = !_showConfirm),
                  icon: Icon(
                    _showConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                validator: (value) =>
                    value == _password.text && (value ?? '').isNotEmpty
                    ? null
                    : 'Passwords must match.',
              ),
              const SizedBox(height: BThereSpacing.sm),
              AuthAgreementRow(
                value: _agreed,
                onChanged: state.loading
                    ? null
                    : (value) => setState(() => _agreed = value ?? false),
              ),
              if (state.failure != null) ...[
                const SizedBox(height: BThereSpacing.md),
                AuthFailureMessage(state.failure!.message, decorated: true),
              ],
              const SizedBox(height: BThereSpacing.lg),
              AuthPrimaryButton(
                label: 'Create Account',
                onPressed: _submit,
                loading: state.loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
