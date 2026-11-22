import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../data/customer_profile_overview_repository.dart';

class ProfileContactSheet extends ConsumerStatefulWidget {
  const ProfileContactSheet({
    super.key,
    required this.owner,
    required this.contacts,
  });
  final int owner;
  final Map<String, dynamic> contacts;
  @override
  ConsumerState<ProfileContactSheet> createState() =>
      _ProfileContactSheetState();
}

class _ProfileContactSheetState extends ConsumerState<ProfileContactSheet> {
  final destination = TextEditingController(),
      otp = TextEditingController(),
      password = TextEditingController();
  String kind = 'email';
  bool busy = false, sent = false, uncertain = false;
  String? error;
  DateTime? expires, resend;
  Timer? timer;
  bool get alive =>
      mounted &&
      ref.read(customerAuthControllerProvider).user?.id == widget.owner &&
      ref.read(customerAuthControllerProvider).stage ==
          CustomerAuthStage.authenticated;
  @override
  void initState() {
    super.initState();
    destination.text = widget.contacts['email'] as String? ?? '';
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && sent) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    destination.dispose();
    otp.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run({bool verify = false}) async {
    if (!alive || busy || uncertain) return;
    if (!verify && resend != null && DateTime.now().isBefore(resend!)) return;
    setState(() {
      busy = true;
      error = null;
    });
    final repository = ref.read(customerProfileOverviewRepositoryProvider);
    try {
      final response = await repository.contact(
        kind,
        destination.text,
        otp: verify ? otp.text.trim() : null,
        password: verify ? password.text : null,
      );
      if (!mounted || !alive) return;
      if (verify) {
        password.clear();
        otp.clear();
        ref.invalidate(customerProfileOverviewProvider(widget.owner));
        Navigator.pop(context);
      } else {
        setState(() {
          sent = true;
          destination.text = response['destination'] as String;
          expires = DateTime.now().add(
            Duration(seconds: response['expiresIn'] as int),
          );
          resend = DateTime.now().add(
            Duration(seconds: response['resendAfterSeconds'] as int),
          );
          otp.clear();
        });
      }
    } on ContactProblem catch (failure) {
      if (mounted && alive) {
        setState(() {
          error = failure.message;
          if (failure.retrySeconds > 0) {
            resend = DateTime.now().add(
              Duration(seconds: failure.retrySeconds),
            );
          }
        });
      }
    } catch (_) {
      if (!mounted || !alive) return;
      if (verify) {
        // An uncertain write is resolved by a read, never automatically repeated.
        try {
          final current = await repository.overview();
          if (!mounted || !alive) return;
          final contacts = current['contacts'] as Map;
          final key = kind == 'email' ? 'email' : 'phoneNumber';
          final expected = kind == 'email'
              ? destination.text.trim().toLowerCase()
              : destination.text.trim();
          if (contacts[key] == expected &&
              contacts[kind == 'email' ? 'emailVerified' : 'phoneVerified'] ==
                  true) {
            ref.invalidate(customerProfileOverviewProvider(widget.owner));
            Navigator.pop(context);
            return;
          }
        } catch (_) {
          /* Leave the write unresolved until the profile is checked. */
        }
        if (mounted && alive) {
          setState(() {
            uncertain = true;
            error = 'Update not confirmed. Close this window and refresh your profile before trying again.';
          });
        }
      } else {
        if (mounted && alive) {
          setState(() {
            error = 'Code delivery could not be confirmed. Please wait before trying again.';
            resend = DateTime.now().add(const Duration(seconds: 60));
          });
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customerAuthControllerProvider);
    if (!alive) return const SizedBox.shrink();
    final remaining = resend?.difference(DateTime.now()).inSeconds ?? 0;
    final expired = expires != null && !DateTime.now().isBefore(expires!);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Manage contact details',
            style: CustomerTypography.section,
          ),
          const SizedBox(height: 16),
          if (!sent) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'email', label: Text('Email')),
                ButtonSegment(value: 'phone', label: Text('Phone')),
              ],
              selected: {kind},
              onSelectionChanged: busy
                  ? null
                  : (values) => setState(() {
                      kind = values.single;
                      destination.text =
                          widget.contacts[kind == 'email'
                                  ? 'email'
                                  : 'phoneNumber']
                              as String? ??
                          '';
                      error = null;
                    }),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('profile-contact-destination'),
              controller: destination,
              enabled: !busy,
              keyboardType: kind == 'email'
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              decoration: InputDecoration(
                labelText: kind == 'email'
                    ? 'Email address'
                    : 'Phone number (+country code)',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your account changes only after you verify the code.',
              style: CustomerTypography.compact,
            ),
          ] else ...[
            Text(
              'Code sent to ${destination.text}',
              style: CustomerTypography.body,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('profile-contact-otp'),
              controller: otp,
              enabled: !busy && !uncertain,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
            TextField(
              key: const ValueKey('profile-contact-password'),
              controller: password,
              enabled: !busy && !uncertain,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Current password (password accounts)',
              ),
            ),
            if (expired)
              const Text(
                'Code expired. Request a new code.',
                style: CustomerTypography.compact,
              ),
            TextButton(
              onPressed: busy || uncertain || remaining > 0
                  ? null
                  : () => run(),
              child: Text(
                remaining > 0 ? 'Resend in $remaining s' : 'Resend code',
              ),
            ),
            TextButton(
              onPressed: busy || uncertain
                  ? null
                  : () => setState(() {
                      sent = false;
                      otp.clear();
                      password.clear();
                      error = null;
                    }),
              child: const Text('Change destination'),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                error!,
                style: CustomerTypography.body.copyWith(
                  color: CustomerColors.error,
                ),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey('profile-contact-submit'),
            onPressed: busy || uncertain || (sent ? expired : remaining > 0)
                ? null
                : () => run(verify: sent),
            child: Text(
              busy
                  ? 'Please wait...'
                  : sent
                  ? 'Verify and save'
                  : 'Send verification code',
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
