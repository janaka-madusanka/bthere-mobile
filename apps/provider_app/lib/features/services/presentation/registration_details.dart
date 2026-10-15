import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../application/service_detail_controller.dart';
import 'registration_widgets.dart';
import 'registration_option_editor.dart';
import 'registration_fields.dart';
import '../application/registration_payload.dart';
import '../domain/provider_service_status.dart';
import 'service_catalog_visuals.dart';

class RegistrationDetails extends ConsumerStatefulWidget {
  const RegistrationDetails({
    required this.value,
    required this.draft,
    required this.onChange,
    required this.onSaveDraft,
    required this.onContinue,
    this.busy = false,
    this.focusedOptionId,
    super.key,
  });
  final ServiceDetailState value;
  final Map<String, dynamic> draft;
  final VoidCallback onChange;
  final Future<bool> Function(Map<String, dynamic>) onSaveDraft;
  final Future<void> Function(Map<String, dynamic>) onContinue;
  final bool busy;
  final int? focusedOptionId;
  @override
  ConsumerState<RegistrationDetails> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<RegistrationDetails> {
  late Map<String, dynamic> draft;
  final _form = GlobalKey<FormState>();
  final Set<int> collapsed = {};
  @override
  void initState() {
    super.initState();
    draft = Map.of(widget.draft);
    if (widget.focusedOptionId != null) {
      collapsed.addAll(
        widget.value.selected.where((id) => id != widget.focusedOptionId),
      );
    }
  }

  ServiceDetailState get value => widget.value;
  List<String> get skills {
    final configured = value.schema.serviceSetup.skills
        .map((s) => s.metadata['name'])
        .whereType<String>()
        .toList();
    return configured;
  }

  Set<String> get selectedSkills =>
      (draft['skills'] as List?)?.whereType<String>().toSet() ?? {};
  Map<String, dynamic>? optionDraft(int id) {
    final raw = draft['options'];
    if (raw is! Map) return null;
    final item = raw['$id'];
    return item is Map ? Map<String, dynamic>.from(item) : null;
  }

  Future<void> editOption(ProviderSchemaOption option) async {
    final ownedFields = option.fields.where((field) {
      if (field.optionIds.isEmpty) return false;
      final applicable = field.optionIds.where(value.selected.contains).toList()
        ..sort();
      return applicable.isNotEmpty && applicable.first == option.optionId;
    }).toList();
    final editableOption = ProviderSchemaOption(
      optionId: option.optionId,
      code: option.code,
      name: option.name,
      fields: ownedFields,
    );
    final current = <String, dynamic>{
      ...optionDraft(option.optionId) ?? {},
      'fields': registrationAnswers(draft),
      'submissions': (draft['server'] as Map? ?? {})['submissions'] ?? [],
      if (draft['availability'] != null) 'availability': draft['availability'],
    };
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => RegistrationOptionEditor(
          option: editableOption,
          service: value.service,
          setup: value.schema.serviceSetup,
          initial: current,
          commonFields: value.schema.commonFields,
          assignmentId: value.assignment?.assignmentId,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    final fieldIds = ownedFields.map((f) => '${f.fieldId}').toSet();
    updated['fields'] = Map<String, dynamic>.from(
      updated['fields'] as Map? ?? {},
    )..removeWhere((key, _) => !fieldIds.contains(key));
    final options = Map<String, dynamic>.from(draft['options'] as Map? ?? {});
    options['${option.optionId}'] = updated;
    setState(
      () => draft = {
        ...draft,
        'options': options,
        'availability': updated['availability'],
      },
    );
    await widget.onSaveDraft(draft);
  }

  Future<void> languages() async {
    final selected =
        (draft['languages'] as List?)?.whereType<String>().toSet() ??
        <String>{};
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                registrationText('Select Languages', 20, bold: true),
                const SizedBox(height: 12),
                for (final language in ['ENGLISH', 'SINHALA', 'TAMIL'])
                  CheckboxListTile(
                    title: Text(
                      language[0] + language.substring(1).toLowerCase(),
                    ),
                    value: selected.contains(language),
                    onChanged: (_) => update(() {
                      if (!selected.remove(language)) selected.add(language);
                    }),
                  ),
                RegistrationButton(
                  'Save Languages',
                  onPressed: () => Navigator.pop(context, selected.toList()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => draft['languages'] = result);
    await widget.onSaveDraft(draft);
  }

  Future<void> availability() async {
    final setup = value.schema.serviceSetup;
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => RegistrationOptionEditor(
          option: ProviderSchemaOption(
            optionId: 0,
            code: 'AVAILABILITY',
            name: value.service.name,
            fields: [],
          ),
          service: value.service,
          initial: {'availability': draft['availability']},
          setup: ProviderServiceSetup(
            serviceTypeId: setup.serviceTypeId,
            name: setup.name,
            availabilityEnabled: true,
            serviceAreasEnabled: false,
            optionsRequired: setup.optionsRequired,
            minimumOptionSelections: setup.minimumOptionSelections,
            maximumOptionSelections: setup.maximumOptionSelections,
            documents: setup.documents,
            skills: setup.skills,
            certificates: setup.certificates,
            education: setup.education,
          ),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => draft['availability'] = updated['availability']);
    await widget.onSaveDraft(draft);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(
      serviceDetailControllerProvider(value.service.id).notifier,
    );
    final selected = value.schema.options
        .where((o) => value.selected.contains(o.optionId))
        .toList();
    final available = value.schema.options
        .where((o) => !value.selected.contains(o.optionId))
        .toList();
    final languageNames =
        (draft['languages'] as List?)
            ?.whereType<String>()
            .map((s) => s.isEmpty ? s : s[0] + s.substring(1).toLowerCase())
            .join(', ') ??
        '';
    return AbsorbPointer(
      absorbing: widget.busy,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RegistrationHeading(
              'Service Details',
              'Tell us more about the service you offer.',
            ),
            RegistrationSection(
              'Selected Service',
              '',
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FBFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 53,
                      height: 53,
                      child:
                          [
                            'caregiver',
                            'caregiving',
                            'home nurse',
                          ].contains(value.service.name.toLowerCase())
                          ? const RegistrationAsset(
                              'details_imgCaregivingSymbol',
                            )
                          : ServiceCatalogSymbol(service: value.service),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          registrationText(value.service.name, 14, bold: true),
                          if (value.service.description != null)
                            registrationText(
                              value.service.description!,
                              10.5,
                              color: registrationMuted,
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onChange,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ),
            RegistrationSection(
              'Languages',
              'Select the languages you speak.',
              child: RegistrationPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -4),
                  minTileHeight: 40,
                  leading: const SizedBox(
                    width: 23,
                    height: 23,
                    child: RegistrationAsset('details_imgLanguagesIcon'),
                  ),
                  title: registrationText(
                    languageNames.isEmpty ? 'Select languages' : languageNames,
                    12,
                  ),
                  trailing: const Icon(Icons.keyboard_arrow_down, size: 20),
                  onTap: languages,
                ),
              ),
            ),
            if (skills.isNotEmpty)
              RegistrationSection(
                'Required Skills',
                'Select the skills you have for this service.',
                child: RegistrationPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      for (final skill in skills)
                        CheckboxListTile(
                          key: ValueKey('skill-$skill'),
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -4),
                          minTileHeight: 40,
                          checkboxScaleFactor: .8,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: registrationText(skill, 12),
                          value: selectedSkills.contains(skill),
                          secondary:
                              value.schema.serviceSetup.skills.any(
                                (s) =>
                                    s.metadata['name'] == skill &&
                                    s.metadata['required'] == true,
                              )
                              ? const _Badge('Required')
                              : null,
                          onChanged: (_) async {
                            final chosen = selectedSkills;
                            if (!chosen.remove(skill)) chosen.add(skill);
                            setState(() => draft['skills'] = chosen.toList());
                            await widget.onSaveDraft(draft);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            if (available.isNotEmpty)
              RegistrationSection(
                'Sub Services',
                'Select the sub services you offer under this service.',
                child: Column(
                  children: [
                    for (final option in available)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: RegistrationPanel(
                          color: option.name.toLowerCase().contains('child')
                              ? const Color(0xFFFFF7F9)
                              : const Color(0xFFF0FCFF),
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            key: ValueKey('sub-service-${option.optionId}'),
                            dense: true,
                            leading: SizedBox(
                              width: 30,
                              height: 30,
                              child: RegistrationAsset(
                                option.name.toLowerCase().contains('child')
                                    ? 'details_imgIllustrationBadge'
                                    : 'details_imgIllustrationBadge1',
                              ),
                            ),
                            title: registrationText(
                              option.name,
                              11,
                              bold: true,
                            ),
                            subtitle:
                                value.schema.options
                                        .where((o) => o.name == option.name)
                                        .length >
                                    1
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      registrationText(
                                        humanizeOptionCode(option.code),
                                        10,
                                        color: registrationMuted,
                                      ),
                                      if (value.schema.options
                                              .where(
                                                (o) =>
                                                    o.name == option.name &&
                                                    o.code == option.code,
                                              )
                                              .length >
                                          1)
                                        registrationText(
                                          'Variant ${option.optionId}',
                                          10,
                                          color: registrationMuted,
                                        ),
                                    ],
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: registrationTeal,
                            ),
                            onTap: () => controller.toggle(option.optionId),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            RegistrationSection(
              'Your Selected Services',
              'Complete the additional details for each selected service.',
              child: Column(
                children: [
                  if (selected.isEmpty)
                    const RegistrationNotice(
                      'Select the services you provide above.',
                    ),
                  for (final option in selected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          RegistrationPanel(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: RegistrationOptionSymbol(
                                        option.name,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => editOption(option),
                                        child: registrationText(
                                          option.name,
                                          15,
                                          bold: true,
                                        ),
                                      ),
                                    ),
                                    _Badge(
                                      optionDraft(option.optionId)?['saved'] ==
                                              true
                                          ? 'Complete'
                                          : 'Incomplete',
                                      complete:
                                          optionDraft(
                                            option.optionId,
                                          )?['saved'] ==
                                          true,
                                    ),
                                    IconButton(
                                      tooltip: 'Expand ${option.name}',
                                      icon: Icon(
                                        collapsed.contains(option.optionId)
                                            ? Icons.keyboard_arrow_right
                                            : Icons.keyboard_arrow_down,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() {
                                        if (!collapsed.remove(
                                          option.optionId,
                                        )) {
                                          collapsed.add(option.optionId);
                                        }
                                      }),
                                    ),
                                  ],
                                ),
                                if (!collapsed.contains(option.optionId)) ...[
                                  for (final (label, asset) in [
                                    ('Experience', 'imgSquareCheck'),
                                    ('Skills', 'imgSkills'),
                                    ('Location & Area', 'imgLocation'),
                                    ('Additional Information', 'imgFileText'),
                                  ])
                                    InkWell(
                                      onTap: () => editOption(option),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: registrationBorder,
                                              width: .6,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 15,
                                              height: 15,
                                              child: RegistrationAsset(
                                                'details_$asset',
                                              ),
                                            ),
                                            const SizedBox(width: 17),
                                            Expanded(
                                              child: registrationText(
                                                label,
                                                12,
                                              ),
                                            ),
                                            registrationText(
                                              label == 'Skills'
                                                  ? '${selectedSkills.length} selected'
                                                  : optionDraft(
                                                          option.optionId,
                                                        )?['saved'] ==
                                                        true
                                                  ? 'Added'
                                                  : 'Not added',
                                              11,
                                              color: registrationMuted,
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          Positioned(
                            left: -10,
                            top: -10,
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                tooltip: 'Remove ${option.name}',
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    controller.toggle(option.optionId),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (selected.isEmpty &&
                value.schema.serviceSetup.availabilityEnabled)
              RegistrationSection(
                'Weekly Availability',
                'Select the days and times you offer this service.',
                child: OutlinedButton(
                  onPressed: availability,
                  child: const Text('Set Availability'),
                ),
              ),
            if (value.schema.commonFields.isNotEmpty)
              RegistrationSection(
                'Additional Information',
                'Tell us about your service.',
                child: RegistrationPanel(
                  child: RegistrationFields(
                    submissions:
                        ((draft['server'] as Map? ?? {})['submissions']
                                    as List? ??
                                [])
                            .whereType<Map>()
                            .toList(),
                    fields: value.schema.commonFields,
                    allFields: activeRegistrationFields(
                      value.schema,
                      value.selected,
                    ),
                    values: draft.putIfAbsent(
                      'fields',
                      () => <String, dynamic>{},
                    ) as Map<String, dynamic>,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
            RegistrationSection(
              'Years of Experience',
              'Your experience offering this service.',
              child: TextFormField(
                key: ValueKey('experience-${value.service.id}'),
                initialValue: value.experience,
                enabled: value.assignment == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter years of experience',
                ),
                onChanged: controller.experience,
                validator: (v) =>
                    double.tryParse(v ?? '') == null || double.parse(v!) < 0
                    ? 'Enter valid years of experience.'
                    : null,
              ),
            ),
            if (value.failure != null)
              RegistrationNotice(value.failure!.message, warning: true),
            if (value.validation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: registrationText(
                  value.validation!,
                  11,
                  color: registrationMuted,
                ),
              ),
            const SizedBox(height: 22),
            RegistrationButton(
              'Continue',
              busy: widget.busy,
              onPressed: value.inconsistent
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      await widget.onContinue(draft);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.complete = false});
  final String label;
  final bool complete;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: complete ? const Color(0xFFE0FAEC) : const Color(0xFFFFF3CE),
      borderRadius: BorderRadius.circular(10),
    ),
    child: registrationText(
      label,
      10,
      bold: true,
      color: complete ? const Color(0xFF078834) : const Color(0xFFB87900),
    ),
  );
}
