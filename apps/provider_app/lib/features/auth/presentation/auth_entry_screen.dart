import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/login_controller.dart';
import '../widgets/auth_page.dart';
import '../widgets/auth_primary_button.dart';

/// Default auth route: sign in. Registration remains a separate existing route.
class AuthEntryScreen extends ConsumerStatefulWidget {
  const AuthEntryScreen({super.key});
  @override
  ConsumerState<AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends ConsumerState<AuthEntryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(loginControllerProvider).loading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .submit(identifier: _email.text.trim(), password: _password.text);
    if (mounted && ref.read(loginControllerProvider).value != null) {
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    return AuthPage(
      signingIn: true,
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
                hint: 'you@example.com',
                prefix: const Icon(Icons.mail_outline),
                controller: _email,
                enabled: !state.loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter your email.' : null,
              ),
              const SizedBox(height: BThereSpacing.md),
              BThereTextField(
                label: 'Password',
                labelPlacement: BThereFieldLabelPlacement.above,
                hint: 'Enter your password',
                prefix: const Icon(Icons.lock_outline),
                controller: _password,
                enabled: !state.loading,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: state.loading
                      ? null
                      : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Enter your password.' : null,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Tooltip(
                  message: 'Password reset is not available yet.',
                  child: TextButton(
                    key: const ValueKey('auth-forgot-password'),
                    onPressed: null,
                    style: TextButton.styleFrom(
                      disabledForegroundColor: BThereColors.primaryAction,
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
              ),
              if (state.failure != null) ...[
                const SizedBox(height: BThereSpacing.md),
                AuthFailureMessage(state.failure!.message, decorated: true),
              ],
              const SizedBox(height: BThereSpacing.lg),
              AuthPrimaryButton(
                label: 'Sign in',
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
