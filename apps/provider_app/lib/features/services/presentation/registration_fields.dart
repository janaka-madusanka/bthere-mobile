import 'package:bthere_common/bthere_common.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../application/registration_payload.dart';
import '../documents/documents_controller.dart';
import 'registration_widgets.dart';

class RegistrationFields extends ConsumerStatefulWidget {
  const RegistrationFields({
    required this.fields,
    required this.values,
    required this.onChanged,
    this.allFields,
    this.answers,
    this.enabled = true,
    this.compact = false,
    this.submissions = const [],
    super.key,
  });
  final List<ProviderRequirementField> fields;
  final List<ProviderRequirementField>? allFields;
  final Map<String, dynamic> values;
  final Map<String, dynamic>? answers;
  final VoidCallback onChanged;
  final bool enabled, compact;
  final List<Map> submissions;
  @override
  ConsumerState<RegistrationFields> createState() => _FieldsState();
}

class _FieldsState extends ConsumerState<RegistrationFields> {
  int? uploading;
  String? error;
  Future<void> upload(ProviderRequirementField field) async {
    if (uploading != null) return;
    setState(() {
      uploading = field.fieldId;
      error = null;
    });
    try {
      final file = await ref.read(documentPickerProvider).pick();
      if (!mounted || file == null) return;
      final extension = file.name.split('.').last.toLowerCase();
      final mime = {
        'pdf': 'application/pdf',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      }[extension];
      final max = field.maximumFileSizeMb;
      if (file.validation != null ||
          (max != null && file.size > max * 1000000) ||
          (field.fieldType == 'IMAGE_UPLOAD' &&
              mime?.startsWith('image/') != true) ||
          (field.allowedFileTypes.isNotEmpty &&
              !field.allowedFileTypes.contains(mime) &&
              !field.allowedFileTypes.contains(extension) &&
              !field.allowedFileTypes.contains('.$extension'))) {
        setState(
          () => error =
              'Choose a supported file within the size limit for ${field.label}.',
        );
        return;
      }
      final result = await ref
          .read(documentsRepositoryProvider)
          .upload(file, (_, _) {});
      if (!mounted) return;
      switch (result) {
        case Success(:final value):
          final files = List<Map<String, dynamic>>.from(
            registrationFiles(widget.values['${field.fieldId}']) ?? const [],
          );
          final multiple = (field.maximumFiles ?? field.minimumFiles ?? 1) > 1;
          if (multiple &&
              field.maximumFiles != null &&
              files.length >= field.maximumFiles!) {
            setState(
              () =>
                  error = 'You can upload at most ${field.maximumFiles} files.',
            );
            return;
          }
          widget.values['${field.fieldId}'] = {
            'files': multiple
                ? [
                    ...files,
                    {'key': value.key},
                  ]
                : [
                    {'key': value.key},
                  ],
          };
          widget.onChanged();
        case Failure(:final failure):
          setState(() => error = failure.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to upload the file. Please retry.');
      }
    } finally {
      if (mounted) setState(() => uploading = null);
    }
  }

  List<({String label, Object value})> choices(ProviderRequirementField field) {
    if (field.options is! List) return [];
    return [
      for (final item in field.options as List)
        if (item is String)
          (label: item, value: item)
        else if (item is Map &&
            item['value'] != null &&
            item['label'] is String)
          (label: item['label'] as String, value: item['value'] as Object),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final field
          in (widget.fields
              .where(
                (f) =>
                    f.status == 'ACTIVE' && f.scope == 'PROVIDER_REQUIREMENT',
              )
              .toList()
            ..sort(
              (a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0),
            )))
        if (registrationFieldVisible(field, {
              ...?widget.answers,
              ...widget.values,
            }, widget.allFields ?? widget.fields) !=
            false)
          Padding(
            key: ValueKey('requirement-${field.fieldId}'),
            padding: EdgeInsets.only(bottom: widget.compact ? 8 : 16),
            child: buildField(field),
          ),
      if (error != null) RegistrationNotice(error!, warning: true),
    ],
  );
  Widget buildField(ProviderRequirementField field) {
    final key = '${field.fieldId}', value = widget.values[key];
    final options = choices(field);
    final submission = widget.submissions
        .where((s) => s['fieldId'] == field.fieldId)
        .firstOrNull;
    final unchanged =
        submission != null &&
        jsonEncode(submission['value']) == jsonEncode(value);
    final review = !unchanged
        ? 'Not submitted'
        : submission['reused'] == true
        ? 'Reused approved answer'
        : switch (submission['verificationStatus']) {
            'APPROVED' => 'Approved',
            'PENDING' => 'Pending review',
            'REJECTED' => 'Rejected',
            _ => 'Status unavailable',
          };
    void change(Object? v) {
      setState(() => widget.values[key] = v);
      widget.onChanged();
    }

    final unsupported =
        registrationFieldVisible(field, {
          ...?widget.answers,
          ...widget.values,
        }, widget.allFields ?? widget.fields) ==
        null;
    Widget control;
    if (unsupported) {
      control = const RegistrationNotice(
        'This field’s condition is not supported. Please refresh the service configuration.',
        warning: true,
      );
    } else if (field.fieldType == 'BOOLEAN') {
      control = DropdownButtonFormField<bool>(
        initialValue: value is bool ? value : null,
        items: const [
          DropdownMenuItem(
            value: true,
            child: Text(
              'Yes',
              style: TextStyle(
                fontFamily: 'HomeInter',
                fontSize: 13,
                color: registrationInk,
              ),
            ),
          ),
          DropdownMenuItem(
            value: false,
            child: Text(
              'No',
              style: TextStyle(
                fontFamily: 'HomeInter',
                fontSize: 13,
                color: registrationInk,
              ),
            ),
          ),
        ],
        onChanged: widget.enabled ? change : null,
        validator: (v) => validateRegistrationAnswer(field, v),
      );
    } else if (field.fieldType == 'SELECT' && options.isNotEmpty) {
      control = DropdownButtonFormField<Object>(
        initialValue: options.any((o) => o.value == value) ? value : null,
        isExpanded: true,
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o.value,
                child: registrationText(o.label, 12),
              ),
            )
            .toList(),
        onChanged: widget.enabled ? change : null,
        validator: (v) => validateRegistrationAnswer(field, v),
      );
    } else if (widget.compact &&
        field.fieldType == 'MULTI_SELECT' &&
        options.isNotEmpty) {
      control = FormField<List>(
        initialValue: value is List ? value : [],
        validator: (_) => validateRegistrationAnswer(field, widget.values[key]),
        builder: (state) => InkWell(
          onTap: !widget.enabled
              ? null
              : () async {
                  final selected = List<Object>.from(
                    widget.values[key] as List? ?? [],
                  );
                  final result = await showModalBottomSheet<List<Object>>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (context) => StatefulBuilder(
                      builder: (context, update) => SafeArea(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .7,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                registrationText(field.label, 18, bold: true),
                                for (final option in options)
                                  CheckboxListTile(
                                    title: Text(option.label),
                                    value: selected.contains(option.value),
                                    onChanged: (_) => update(() {
                                      if (!selected.remove(option.value)) {
                                        selected.add(option.value);
                                      }
                                    }),
                                  ),
                                RegistrationButton(
                                  'Save',
                                  onPressed: () =>
                                      Navigator.pop(context, selected),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  if (result != null && mounted) {
                    change(result);
                    state.didChange(result);
                  }
                },
          child: InputDecorator(
            decoration: InputDecoration(errorText: state.errorText),
            child: Row(
              children: [
                Expanded(
                  child: registrationText(
                    options
                        .where(
                          (option) => (widget.values[key] as List? ?? [])
                              .contains(option.value),
                        )
                        .map((option) => option.label)
                        .join(', '),
                    13,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
          ),
        ),
      );
    } else if (field.fieldType == 'MULTI_SELECT' && options.isNotEmpty) {
      control = FormField<List>(
        initialValue: value is List ? value : [],
        validator: (_) => validateRegistrationAnswer(field, widget.values[key]),
        builder: (state) => Column(
          children: [
            for (final option in options)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: registrationText(option.label, 12),
                value: (widget.values[key] as List? ?? []).contains(
                  option.value,
                ),
                onChanged: widget.enabled
                    ? (_) {
                        final selected = List<Object>.from(
                          widget.values[key] as List? ?? [],
                        );
                        if (!selected.remove(option.value)) {
                          selected.add(option.value);
                        }
                        change(selected);
                        state.didChange(selected);
                      }
                    : null,
              ),
            if (state.errorText != null)
              registrationText(state.errorText!, 11, color: Colors.red),
          ],
        ),
      );
    } else if ([
      'IMAGE_UPLOAD',
      'DOCUMENT_UPLOAD',
      'FILE_UPLOAD',
    ].contains(field.fieldType)) {
      control = FormField<Object>(
        validator: (_) => validateRegistrationAnswer(field, widget.values[key]),
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: !widget.enabled || uploading != null
                  ? null
                  : () => upload(field),
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(
                uploading == field.fieldId
                    ? 'Uploading…'
                    : registrationFiles(value)?.isNotEmpty == true
                    ? 'Replace uploaded file'
                    : 'Choose file',
              ),
            ),
            if (registrationFiles(value) case final files?) ...[
              for (var i = 0; i < files.length; i++)
                Row(
                  children: [
                    Expanded(
                      child: registrationText(
                        'Uploaded file ${i + 1}',
                        10,
                        color: registrationTeal,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove uploaded file',
                      onPressed: !widget.enabled
                          ? null
                          : () {
                              final updated = List<Map<String, dynamic>>.from(
                                files,
                              )..removeAt(i);
                              final next = {'files': updated};
                              change(next);
                              state.didChange(next);
                            },
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
            ],
            if (registrationFiles(value)?.isNotEmpty == true)
              registrationText('File uploaded', 10, color: registrationTeal),
            if (state.errorText != null)
              registrationText(state.errorText!, 11, color: Colors.red),
          ],
        ),
      );
    } else if (['DATE', 'TIME'].contains(field.fieldType)) {
      control = FormField<Object>(
        validator: (_) => validateRegistrationAnswer(field, widget.values[key]),
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: !widget.enabled
                  ? null
                  : () async {
                      if (field.fieldType == 'DATE') {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(value?.toString() ?? '') ??
                              DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                        );
                        if (date != null && mounted) {
                          change(date.toIso8601String().substring(0, 10));
                          state.didChange(widget.values[key]);
                        }
                      } else {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (time != null && mounted) {
                          change(
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
                          );
                          state.didChange(widget.values[key]);
                        }
                      }
                    },
              child: Text(
                value?.toString() ?? 'Select ${field.fieldType.toLowerCase()}',
              ),
            ),
            if (state.errorText != null)
              registrationText(state.errorText!, 11, color: Colors.red),
          ],
        ),
      );
    } else if ([
      'TEXT',
      'TEXTAREA',
      'NUMBER',
      'PHONE',
      'EMAIL',
    ].contains(field.fieldType)) {
      control = TextFormField(
        key: ValueKey('dynamic-field-$key'),
        initialValue: value?.toString() ?? '',
        enabled: widget.enabled,
        style: const TextStyle(fontSize: 12, fontFamily: 'HomeInter'),
        maxLines: field.fieldType == 'TEXTAREA' ? 3 : 1,

        decoration: const InputDecoration(
          counterStyle: TextStyle(
            fontFamily: 'HomeInter',
            fontSize: 11,
            color: registrationMuted,
          ),
        ),
        keyboardType: switch (field.fieldType) {
          'NUMBER' => const TextInputType.numberWithOptions(decimal: true),
          'EMAIL' => TextInputType.emailAddress,
          'PHONE' => TextInputType.phone,
          _ => TextInputType.text,
        },
        onChanged: (v) {
          widget.values[key] = field.fieldType == 'NUMBER'
              ? num.tryParse(v) ?? v
              : v;
          widget.onChanged();
        },
        validator: (_) => validateRegistrationAnswer(field, widget.values[key]),
      );
    } else {
      control = const RegistrationNotice(
        'This field needs a supported service configuration. Please refresh.',
        warning: true,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        registrationText(
          '${field.label}${field.required ? ' *' : ''}',
          widget.compact ? 13 : 12,
        ),
        if (field.description != null)
          registrationText(field.description!, 10, color: registrationMuted),
        const SizedBox(height: 7),
        control,
        if (field.requiresApproval)
          registrationText(
            review,
            9,
            color: review == 'Rejected' ? Colors.red : registrationMuted,
          ),
        if (unchanged &&
            submission['verificationStatus'] == 'REJECTED' &&
            submission['reviewNote'] is String)
          registrationText(
            submission['reviewNote'] as String,
            10,
            color: Colors.red,
          ),
      ],
    );
  }
}
