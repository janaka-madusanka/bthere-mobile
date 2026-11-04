import 'package:flutter/material.dart';

/// Collect only gateway-required contact details absent from the signed-in user.
class BookingBillingContactDialog extends StatefulWidget {
  const BookingBillingContactDialog({
    super.key,
    this.email = '',
    this.phone = '',
  });
  final String email, phone;
  @override
  State<BookingBillingContactDialog> createState() =>
      _BookingBillingContactDialogState();
}

class _BookingBillingContactDialogState
    extends State<BookingBillingContactDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  late final _phone = TextEditingController(text: widget.phone);
  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    title: const Text('Payment contact details'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PayHere needs your email and phone number for this payment.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (value) =>
                  RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid phone number',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (_email.text.trim(), _phone.text.trim()));
          }
        },
        child: const Text('Continue to payment'),
      ),
    ],
  );
}
