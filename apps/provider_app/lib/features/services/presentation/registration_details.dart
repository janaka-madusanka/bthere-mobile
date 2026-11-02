import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../application/service_detail_controller.dart';
import 'registration_widgets.dart';
import 'registration_option_editor.dart';
import 'registration_fields.dart';
import '../application/registration_payload.dart';
import '../domain/provider_service_status.dart';
import 'registration_option_summary.dart';
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
  final _skillsKey = GlobalKey();
  late final bool needsExperience;
  @override
  void initState() {
    super.initState();
    draft = Map.of(widget.draft);
    needsExperience = widget.value.experience.isEmpty;
    if (widget.focusedOptionId != null) {
      collapsed.addAll(
        widget.value.selected.where((id) => id != widget.focusedOptionId),
      );
    }
  }

  ServiceDetailState get value => widget.value;
  @override
  void didUpdateWidget(covariant RegistrationDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.draft, widget.draft)) {
      draft = Map.of(widget.draft);
    }
  }

  List<String> get skills {
    final configured = value.schema.serviceSetup.skills
        .map((s) => s.metadata['name'])
        .whereType<String>()
        .toList();
    return configured;
  }

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
      description: option.description,
      icon: option.icon,
      deliveryModes: option.deliveryModes,
      displayOrder: option.displayOrder,
      locationEnabled: option.locationEnabled,
      defaultCapacity: option.defaultCapacity,
      bookingMode: option.bookingMode,
    );
    final current = <String, dynamic>{
      ...?optionDraft(option.optionId),
      'fields': registrationAnswers(draft, selected: value.selected),
      'submissions': (draft['server'] as Map? ?? {})['submissions'] ?? [],
      if (draft['availability'] != null) 'availability': draft['availability'],
    };
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: RegistrationOptionEditor(
          asSheet: true,
          option: editableOption,
          service: value.service,
          setup: value.schema.serviceSetup,
          initial: current,
          commonFields: activeRegistrationFields(value.schema, value.selected),
          assignmentId: value.assignment?.assignmentId,
          loadSavedLocations: value.registered.any(
            (registered) => registered.optionId == option.optionId,
          ),
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
    final selected = registrationLanguages(draft['languages']).toSet();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
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
      ),
    );
    if (!mounted || result == null) return;
    setState(
      () => draft = {...draft, 'languages': result, '_languagesEdited': true},
    );
    await widget.onSaveDraft(draft);
  }

  Future<void> experience() async {
    final form = GlobalKey<FormState>();
    var years = value.experience;
    final changed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                registrationText('Years of Experience', 20, bold: true),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: years,
                  readOnly: value.assignment != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Years of Experience',
                  ),
                  onChanged: (text) => years = text,
                  validator: (text) {
                    final number = double.tryParse(text ?? '');
                    return number == null || !number.isFinite || number < 0
                        ? 'Enter valid years of experience.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                RegistrationButton(
                  value.assignment == null ? 'Save Experience' : 'Done',
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      Navigator.pop(context, years);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (changed == null || !mounted || value.assignment != null) return;
    ref
        .read(serviceDetailControllerProvider(value.service.id).notifier)
        .experience(changed);
  }

  Future<void> availability() async {
    final setup = value.schema.serviceSetup;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: RegistrationOptionEditor(
          asSheet: true,
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
        .where(
          (o) =>
              !value.selected.contains(o.optionId) &&
              !value.registrationSources.containsKey(o.optionId),
        )
        .toList();
    final languageNames = registrationLanguages(draft['languages'])
        .map((language) => language[0] + language.substring(1).toLowerCase())
        .join(', ');
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
                      child: ServiceCatalogSymbol(service: value.service),
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
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE0F8F6),
                        foregroundColor: registrationTeal,
                        minimumSize: const Size(71, 33),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                  minLeadingWidth: 28,
                  horizontalTitleGap: 8,
                  contentPadding: const EdgeInsets.only(left: 8, right: 16),
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
                'Skills',
                'Select the skills you have for this service.',
                child: RegistrationPanel(
                  key: _skillsKey,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final (index, skill)
                          in value.schema.serviceSetup.skills.indexed)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == skills.length - 1
                                    ? Colors.transparent
                                    : registrationBorder,
                                width: .6,
                              ),
                            ),
                          ),
                          child: CheckboxListTile(
                            key: ValueKey('skill-${skill.metadata['skillId']}'),
                            dense: true,
                            visualDensity: const VisualDensity(
                              vertical: -4,
                              horizontal: -4,
                            ),
                            minTileHeight: 40,
                            checkboxScaleFactor: .8,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: registrationText(
                              '${skill.metadata['name']}',
                              12,
                            ),
                            value: registrationSkillIds(
                              value.schema,
                              draft,
                            ).contains(skill.metadata['skillId']),
                            secondary: skill.metadata['required'] == true
                                ? const _Badge('Required', compact: true)
                                : null,
                            onChanged: (_) async {
                              final chosen = registrationSkillIds(
                                value.schema,
                                draft,
                              );
                              final id = skill.metadata['skillId'] as int;
                              if (!chosen.remove(id)) chosen.add(id);
                              setState(() {
                                draft['skillIds'] = chosen.toList();
                                draft['skills'] = [
                                  for (final item
                                      in value.schema.serviceSetup.skills)
                                    if (chosen.contains(
                                      item.metadata['skillId'],
                                    ))
                                      item.metadata['name'],
                                ];
                              });
                              await widget.onSaveDraft(draft);
                            },
                          ),
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
                          color: registrationOptionSurface(option),
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            key: ValueKey('sub-service-${option.optionId}'),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -4),
                            minTileHeight: 40,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            leading: SizedBox(
                              width: 30,
                              height: 30,
                              child: RegistrationOptionArtwork(option: option),
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
            if (value.schema.options.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        registrationText(
                          'Your Selected Services',
                          13,
                          bold: true,
                        ),
                        registrationText(
                          'Complete the additional details for each selected service.',
                          10.5,
                          color: registrationMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F8F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: registrationText(
                      '${selected.length} selected',
                      10,
                      color: registrationTeal,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (selected.isEmpty &&
                value.schema.options.isNotEmpty &&
                value.schema.serviceSetup.optionsRequired)
              const Padding(
                padding: EdgeInsets.only(bottom: 22),
                child: RegistrationNotice(
                  'Select the services you provide above.',
                ),
              ),
            for (final option in selected)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: RegistrationOptionSummary(
                  option: option,
                  schema: value.schema,
                  selected: value.selected,
                  draft: draft,
                  experience: value.experience,
                  expanded: !collapsed.contains(option.optionId),
                  onToggle: () => setState(() {
                    if (!collapsed.remove(option.optionId)) {
                      collapsed.add(option.optionId);
                    }
                  }),
                  onRemove: () => controller.toggle(option.optionId),
                  onEdit: () => editOption(option),
                  onExperience: experience,
                  onSkills: () {
                    final target = _skillsKey.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: const Duration(milliseconds: 250),
                      );
                    }
                  },
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
            if (activeRegistrationFields(
              value.schema,
              value.selected,
            ).any((f) => f.optionIds.isEmpty))
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
                    answers: registrationAnswers(
                      draft,
                      selected: value.selected,
                    ),
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
            if (needsExperience || selected.isEmpty)
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
  const _Badge(this.label, {this.compact = false});
  final String label;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 4 : 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3CE),
      borderRadius: BorderRadius.circular(10),
    ),
    child: registrationText(
      label,
      10,
      bold: true,
      color: const Color(0xFFB87900),
    ),
  );
}
