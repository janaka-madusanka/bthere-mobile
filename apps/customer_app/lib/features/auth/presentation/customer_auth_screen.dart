import '../../../app/customer_theme.dart';

import 'dart:async';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/customer_auth_controller.dart';
import '../data/customer_auth_service.dart';
import 'customer_auth_page.dart';
import 'customer_verification_page.dart';

class CustomerAuthScreen extends ConsumerStatefulWidget {
  const CustomerAuthScreen({super.key});
  @override
  ConsumerState<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends ConsumerState<CustomerAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController(),
      _otp = TextEditingController(),
      _phone = TextEditingController();
  bool _register = false, _visible = false, _confirmVisible = false;
  bool _phoneMode = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _identifier.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(customerAuthControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phoneVerification = controller.verificationPhone != null;
        final verifying =
            controller.verificationEmail != null || phoneVerification;
        final busy = controller.busy;
        final remaining =
            controller.resendAt
                ?.difference(controller.service.now())
                .inSeconds ??
            0;
        Future<void> submit() async {
          if (busy || !_form.currentState!.validate()) return;
          FocusScope.of(context).unfocus();
          if (verifying) {
            if (phoneVerification) {
              await controller.verifyPhoneOtp(_otp.text);
            } else {
              await controller.verify(_otp.text);
            }
          } else if (_phoneMode) {
            await controller.requestPhoneOtp(_phone.text);
          } else if (_register) {
            await controller.register(_identifier.text, _password.text);
          } else {
            await controller.login(_identifier.text, _password.text);
          }
          if (mounted && controller.verificationEmail != null) {
            _password.clear();
            _confirm.clear();
          }
        }

        if (verifying) {
          void changeDestination() {
            _otp.clear();
            controller.cancelVerification();
            setState(() {
              _register = !phoneVerification;
              _phoneMode = phoneVerification;
            });
          }

          return PopScope(
            canPop: !busy && !verifying,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !busy) changeDestination();
            },
            child: CustomerVerificationPage(
              formKey: _form,
              otp: _otp,
              phone: phoneVerification,
              destination:
                  controller.verificationPhone ??
                  controller.verificationEmail ??
                  '',
              remaining: remaining,
              busy: busy,
              error: controller.error,
              onSubmit: submit,
              onResend: controller.resend,
              onChangeDestination: changeDestination,
            ),
          );
        }

        return PopScope(
          canPop: !busy && !verifying,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !busy && verifying) controller.cancelVerification();
          },
          child: CustomerAuthPage(
            registering: _register,
            verifying: verifying,
            busy: busy,
            onModeChanged: (value) {
              setState(() {
                _register = value;
                _phoneMode = false;
                _otp.clear();
                _password.clear();
                _confirm.clear();
              });
              _form.currentState?.reset();
            },
            child: Form(
              key: _form,
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_phoneMode) ...[
                      BThereTextField(
                        key: const ValueKey('customer-phone'),
                        controller: _phone,
                        enabled: !busy,
                        label: 'Mobile number',
                        labelPlacement: BThereFieldLabelPlacement.above,
                        hint: '+94771234567',
                        prefix: const Icon(Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        autocorrect: false,
                        validator: (value) => validPhoneNumber(value ?? '')
                            ? null
                            : 'Use country code, for example +94771234567.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use your country code. A new number creates a Customer account; an existing number signs in.',
                      ),
                    ] else ...[
                      BThereTextField(
                        key: const ValueKey('customer-identifier'),
                        controller: _identifier,
                        enabled: !busy,
                        label: _register
                            ? 'Email address'
                            : 'Email or username',
                        labelPlacement: BThereFieldLabelPlacement.above,
                        hint: 'you@example.com',
                        prefix: const Icon(Icons.mail_outline),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: [
                          _register
                              ? AutofillHints.email
                              : AutofillHints.username,
                        ],
                        validator: (v) => _register
                            ? validEmail(v ?? '')
                                  ? null
                                  : 'Enter a valid email.'
                            : (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Enter your email or username.',
                      ),
                      const SizedBox(height: 16),
                      BThereTextField(
                        key: const ValueKey('customer-password'),
                        controller: _password,
                        enabled: !busy,
                        label: 'Password',
                        labelPlacement: BThereFieldLabelPlacement.above,
                        hint: _register
                            ? 'Create a secure password'
                            : 'Enter your password',
                        prefix: const Icon(Icons.lock_outline),
                        obscureText: !_visible,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        suffix: IconButton(
                          tooltip: _visible ? 'Hide password' : 'Show password',
                          onPressed: busy
                              ? null
                              : () => setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        validator: (v) {
                          final n = (v ?? '').runes.length;
                          return _register
                              ? n >= 10 && n <= 72
                                    ? null
                                    : 'Use 10–72 characters.'
                              : (v?.trim().isNotEmpty ?? false)
                              ? null
                              : 'Enter your password.';
                        },
                      ),
                      if (_register) ...[
                        const SizedBox(height: 8),
                        const Text('Use 10–72 characters for your password.'),
                        const SizedBox(height: 16),
                        BThereTextField(
                          key: const ValueKey('customer-confirm'),
                          controller: _confirm,
                          enabled: !busy,
                          label: 'Confirm password',
                          labelPlacement: BThereFieldLabelPlacement.above,
                          hint: 'Confirm your password',
                          prefix: const Icon(Icons.lock_outline),
                          obscureText: !_confirmVisible,
                          suffix: IconButton(
                            tooltip: _confirmVisible
                                ? 'Hide confirm password'
                                : 'Show confirm password',
                            onPressed: busy
                                ? null
                                : () => setState(
                                    () => _confirmVisible = !_confirmVisible,
                                  ),
                            icon: Icon(
                              _confirmVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (v) => v == _password.text
                              ? null
                              : 'Passwords must match.',
                        ),
                      ],
                    ],
                    if (!verifying && !_register && !_phoneMode)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      await controller.resumeVerification(
                                        _identifier.text,
                                      );
                                      if (mounted &&
                                          controller.verificationEmail !=
                                              null) {
                                        _password.clear();
                                      }
                                    },
                              style: TextButton.styleFrom(
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontSize: 14, height: 1.2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Verify email'),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Tooltip(
                                message: 'Password reset is not available yet.',
                                child: TextButton(
                                  onPressed: null,
                                  style: TextButton.styleFrom(
                                    disabledForegroundColor:
                                        CustomerColors.action,
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontSize: 14, height: 1.2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: _register || verifying ? 20 : 8),
                    if (controller.error case final error?) ...[
                      BThereInlineError(error),
                      const SizedBox(height: 16),
                    ],
                    BTherePrimaryButton(
                      key: const ValueKey('customer-auth-submit'),
                      label: _phoneMode
                          ? remaining > 0
                                ? 'Send code in ${remaining + 1}s'
                                : 'Send code'
                          : _register
                          ? 'Create account'
                          : 'Sign in',
                      loading: busy,
                      onPressed: !verifying && _phoneMode && remaining > 0
                          ? null
                          : submit,
                    ),
                    if (!verifying)
                      TextButton(
                        key: const ValueKey('customer-phone-mode'),
                        onPressed: busy
                            ? null
                            : () {
                                setState(() {
                                  _phoneMode = !_phoneMode;
                                  _otp.clear();
                                  _password.clear();
                                  _confirm.clear();
                                });
                                controller.cancelVerification();
                                _form.currentState?.reset();
                              },
                        child: Text(
                          _phoneMode
                              ? 'Continue with email'
                              : 'Continue with phone',
                        ),
                      ),
                    if (_register || verifying) const SizedBox(height: 12),
                    if (_register)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                setState(() {
                                  _register = !_register;
                                  _password.clear();
                                  _confirm.clear();
                                });
                                _form.currentState?.reset();
                              },
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'Create an account',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
