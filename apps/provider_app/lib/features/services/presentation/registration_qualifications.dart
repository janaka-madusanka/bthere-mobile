import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../application/service_providers.dart';
import '../data/registration_repository.dart';
import '../documents/documents_controller.dart';
import 'registration_widgets.dart';

final registrationQualificationsProvider = FutureProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>>, (int, String)>(
      (ref, key) => ref.watch(registrationRepositoryProvider).safe(() async {
        final raw = await ref
            .read(registrationRepositoryProvider)
            .read(key.$1, key.$2);
        if (raw is! List) throw const FormatException('Invalid qualifications');
        return raw.map((v) => Map<String, dynamic>.from(v as Map)).toList();
      }),
      dependencies: [registrationRepositoryProvider],
    );

class RegistrationQualifications extends ConsumerWidget {
  const RegistrationQualifications({
    required this.assignmentId,
    required this.setup,
    super.key,
  });
  final int assignmentId;
  final ProviderServiceSetup setup;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      for (final (resource, level) in [
        ('certificates', setup.certificates.level),
        ('education', setup.education.level),
      ])
        if (level != ProviderRequirementLevel.disabled)
          RegistrationSection(
            resource == 'certificates' ? 'Certifications' : 'Education',
            level == ProviderRequirementLevel.required
                ? 'Required for this service.'
                : 'Optional supporting qualifications.',
            child: Builder(
              builder: (context) {
                final provider = registrationQualificationsProvider((
                  assignmentId,
                  resource,
                ));
                final result = ref.watch(provider), data = result.asData?.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (result.isLoading) const LinearProgressIndicator(),
                    if (data is Success<List<Map<String, dynamic>>>) ...[
                      for (final record in data.value)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.description_outlined,
                            color: registrationTeal,
                          ),
                          title: registrationText(
                            '${record['name'] ?? record['qualificationName']}',
                            12,
                            bold: true,
                          ),
                          subtitle: registrationText(
                            '${record['verificationStatus']}${record['rejectionReason'] == null ? '' : ' · ${record['rejectionReason']}'}',
                            10,
                            color: registrationMuted,
                          ),
                        ),
                    ],
                    if (result.hasError || data is Failure)
                      TextButton(
                        onPressed: () => ref.invalidate(provider),
                        child: const Text('Retry loading qualifications'),
                      ),
                    OutlinedButton.icon(
                      onPressed: result.isLoading
                          ? null
                          : () async {
                              final saved = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                isDismissible: false,
                                enableDrag: false,
                                builder: (_) => _QualificationForm(
                                  assignmentId: assignmentId,
                                  resource: resource,
                                ),
                              );
                              if (saved == true) ref.invalidate(provider);
                            },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        resource == 'certificates'
                            ? 'Add Certificate'
                            : 'Add Education',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
    ],
  );
}

class _QualificationForm extends ConsumerStatefulWidget {
  const _QualificationForm({
    required this.assignmentId,
    required this.resource,
  });
  final int assignmentId;
  final String resource;
  @override
  ConsumerState<_QualificationForm> createState() => _QualificationState();
}

class _QualificationState extends ConsumerState<_QualificationForm> {
  final form = GlobalKey<FormState>();
  final values = <String, dynamic>{};
  bool busy = false;
  String? error, fileName;
  bool get certificate => widget.resource == 'certificates';
  Future<void> pick() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await ref.read(documentPickerProvider).pick();
      if (!mounted || file == null) return;
      if (file.validation != null) {
        setState(() => error = file.validation);
        return;
      }
      final result = await ref
          .read(documentsRepositoryProvider)
          .upload(file, (_, _) {});
      if (!mounted) return;
      if (result case Success(:final value)) {
        values['documentKey'] = value.key;
        setState(() => fileName = file.name);
      } else if (result case Failure(:final failure)) {
        setState(() => error = failure.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to upload supporting file. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (values['documentKey'] == null) {
      setState(() => error = 'Upload a supporting document.');
      return;
    }
    final from = values[certificate ? 'issuedDate' : 'startDate'] as String?;
    final to = values[certificate ? 'expiryDate' : 'completionDate'] as String?;
    if (from != null && to != null && to.compareTo(from) < 0) {
      setState(() => error = 'End date must not be before the start date.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(registrationRepositoryProvider);
      // Reconcile a retry after a lost POST response before creating another record.
      final existing = await repo.safe(
        () => repo.read(widget.assignmentId, widget.resource),
      );
      if (existing is Failure) {
        if (mounted) {
          setState(
            () => error =
                'Unable to check existing qualifications. Please retry.',
          );
        }
        return;
      }
      final records = (existing as Success<Object?>).value;
      final duplicate =
          records is List &&
          records.whereType<Map>().any(
            (r) => r['documentKey'] == values['documentKey'],
          );
      final result = duplicate
          ? const Success<void>(null)
          : await repo.addQualification(widget.assignmentId, widget.resource, {
              ...values,
              if (certificate) 'expiryDate': values['expiryDate'],
            });
      if (!mounted) return;
      if (result case Failure(:final failure)) {
        setState(() => error = failure.message);
        return;
      }
      ref.read(providerCompletionControllerProvider.notifier).reload();
      ref.invalidate(providerAssignmentsProvider);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to save qualification. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    bool date = false,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('$key-${date ? values[key] : ''}'),
      initialValue: values[key]?.toString(),
      enabled: !busy,
      readOnly: date,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: date
            ? const Icon(Icons.calendar_today_outlined, size: 18)
            : null,
      ),
      onTap: !date
          ? null
          : () async {
              final value = await showDatePicker(
                context: context,
                initialDate:
                    DateTime.tryParse(values[key] ?? '') ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (value != null && mounted) {
                setState(
                  () => values[key] = value.toIso8601String().substring(0, 10),
                );
              }
            },
      onChanged: (v) => values[key] = v.trim(),
      validator: (v) =>
          required && (v == null || v.trim().isEmpty) ? 'Required' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              registrationText(
                certificate ? 'Add Certificate' : 'Add Education',
                22,
                bold: true,
              ),
              const SizedBox(height: 20),
              if (certificate) ...[
                field('name', 'Certificate name'),
                field('issuingOrganization', 'Issuing organization'),
                field('certificateNumber', 'Certificate number'),
                field('issuedDate', 'Issued date', date: true),
                field(
                  'expiryDate',
                  'Expiry date (optional)',
                  date: true,
                  required: false,
                ),
              ] else ...[
                field('qualificationName', 'Qualification name'),
                field('instituteName', 'Institute name'),
                field('fieldOfStudy', 'Field of study'),
                field('startDate', 'Start date', date: true),
                field('completionDate', 'Completion date', date: true),
                field('result', 'Result'),
              ],
              OutlinedButton.icon(
                onPressed: busy ? null : pick,
                icon: const Icon(Icons.upload_file),
                label: Text(fileName ?? 'Upload Supporting Document'),
              ),
              if (error != null) RegistrationNotice(error!, warning: true),
              const SizedBox(height: 14),
              RegistrationButton('Save', onPressed: save, busy: busy),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
