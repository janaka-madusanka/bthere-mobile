import 'package:flutter/material.dart';

import '../data/registration_repository.dart';
import 'registration_widgets.dart';

Future<Map<String, dynamic>?> showRegistrationLocation(
  BuildContext context, {
  Map<String, dynamic>? initial,
  required String mode,
}) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _LocationForm(initial: initial ?? {}, mode: mode),
);

class _LocationForm extends StatefulWidget {
  const _LocationForm({required this.initial, required this.mode});
  final Map<String, dynamic> initial;
  final String mode;
  @override
  State<_LocationForm> createState() => _LocationState();
}

class _LocationState extends State<_LocationForm> {
  final form = GlobalKey<FormState>();
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = Map.of(widget.initial);
  }

  Widget field(
    String key,
    String label, {
    bool required = false,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: values[key]?.toString(),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => values[key] = numeric ? num.tryParse(v) : v.trim(),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) return 'Required';
        if (numeric && v?.isNotEmpty == true) {
          final n = num.tryParse(v!);
          if (n == null || !n.isFinite) return 'Enter a valid number.';
          if (key == 'latitude' && (n < -90 || n > 90)) {
            return 'Latitude must be between -90 and 90.';
          }
          if (key == 'longitude' && (n < -180 || n > 180)) {
            return 'Longitude must be between -180 and 180.';
          }
          if (key == 'radiusKm' && n <= 0) return 'Enter a positive radius.';
          if (key == 'capacity' && (n < 1 || n != n.round())) {
            return 'Enter a whole number, at least 1.';
          }
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            registrationText('Service Location', 22, bold: true),
            const SizedBox(height: 20),
            field('locationName', 'Location name', required: true),
            field('country', 'Country', required: true),
            field('province', 'Province'),
            field('district', 'District'),
            field('city', 'City', required: true),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(
                    'latitude',
                    'Latitude',
                    required: true,
                    numeric: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(
                    'longitude',
                    'Longitude',
                    required: true,
                    numeric: true,
                  ),
                ),
              ],
            ),
            if (widget.mode == RegistrationRepository.physicalModes.first)
              field(
                'radiusKm',
                'Service radius (km)',
                required: true,
                numeric: true,
              ),
            field('capacity', 'Capacity', required: true, numeric: true),
            RegistrationButton(
              'Save Location',
              onPressed: () {
                if (!form.currentState!.validate()) return;
                if (widget.mode == 'CUSTOMER_TO_PROVIDER') {
                  values['radiusKm'] = null;
                }
                Navigator.pop(context, values);
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
