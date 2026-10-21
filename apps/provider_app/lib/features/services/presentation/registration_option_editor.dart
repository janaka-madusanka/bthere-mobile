import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bthere_common/bthere_common.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../data/registration_repository.dart';
import 'registration_fields.dart';
import 'registration_location_editor.dart';
import 'registration_widgets.dart';
import 'registration_unavailable_dates.dart';
import 'registration_option_summary.dart';

part 'registration_configured_locations.dart';

class RegistrationOptionEditor extends ConsumerStatefulWidget {
  const RegistrationOptionEditor({
    required this.option,
    required this.service,
    required this.setup,
    required this.initial,
    this.commonFields = const [],
    this.assignmentId,
    this.loadSavedLocations = true,
    this.isServiceUpdate = false,
    this.firstStep = 1,
    this.asSheet = false,
    this.onSave,
    this.onBack,
    this.busy = false,
    this.saveError,
    super.key,
  });
  final ProviderSchemaOption option;
  final ProviderServiceType service;
  final ProviderServiceSetup setup;
  final List<ProviderRequirementField> commonFields;
  final int? assignmentId;
  final bool loadSavedLocations;
  final bool isServiceUpdate;
  final int firstStep;
  final bool asSheet;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>)? onSave;
  final VoidCallback? onBack;
  final bool busy;
  final String? saveError;
  @override
  ConsumerState<RegistrationOptionEditor> createState() => _OptionState();
}

class _OptionState extends ConsumerState<RegistrationOptionEditor> {
  final form = GlobalKey<FormState>();
  late Map<String, dynamic> values, fields;
  late Set<int> days;
  String? error;
  late List<String> locationModes;
  final locationKeys = <String, GlobalKey<_ConfiguredLocationState>>{};
  bool anyTime = true, anyDay = false;
  bool availabilityChanged = false;
  bool timesChanged = false;
  TimeOfDay start = const TimeOfDay(hour: 8, minute: 0),
      end = const TimeOfDay(hour: 17, minute: 0);
  @override
  void initState() {
    super.initState();
    values = Map.of(widget.initial);
    fields = Map<String, dynamic>.from(values['fields'] as Map? ?? {});
    locationModes = widget.option.configuredLocationModes(
      values['deliveryMode'],
    );
    for (final mode in locationModes.where((m) => m != 'ONLINE')) {
      locationKeys[mode] = GlobalKey<_ConfiguredLocationState>();
    }
    final availability = values['availability'] as Map? ?? {};
    anyTime = availability['availableAnyTime'] != false;
    anyDay = availability['availableAnyDay'] == true;
    final slots = (availability['weeklySlots'] as List? ?? [])
        .whereType<Map>()
        .toList();
    days = {
      for (final s in slots)
        RegistrationRepository.weekdays.indexOf(s['dayOfWeek'] as String),
    }..remove(-1);
    if (slots.isNotEmpty && !anyTime) {
      TimeOfDay parse(Object? raw, TimeOfDay fallback) {
        if (!RegistrationRepository.validTime(raw)) return fallback;
        final pieces = (raw as String).split(':');
        return TimeOfDay(
          hour: int.parse(pieces[0]),
          minute: int.parse(pieces[1]),
        );
      }

      start = parse(slots.first['startTime'], start);
      end = parse(slots.first['endTime'], end);
    }
  }

  Future<void> availabilitySettings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        void change(VoidCallback action) {
          setState(action);
          update(() {});
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                registrationText('Availability settings', 20, bold: true),
                registrationText(
                  'Availability is shared across this service?s options.',
                  12,
                  color: registrationMuted,
                ),
                SwitchListTile(
                  title: const Text('Available every day'),
                  value: anyDay,
                  onChanged: (value) => change(() {
                    anyDay = value;
                    if (value) anyTime = true;
                    availabilityChanged = true;
                  }),
                ),
                SwitchListTile(
                  title: const Text('Available all day'),
                  value: anyTime,
                  onChanged: anyDay
                      ? null
                      : (value) => change(() {
                          anyTime = value;
                          timesChanged = true;
                          availabilityChanged = true;
                        }),
                ),
                if (!anyTime)
                  Row(
                    children: [
                      for (final isStart in [true, false])
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: isStart ? start : end,
                              );
                              if (selected != null &&
                                  mounted &&
                                  context.mounted) {
                                change(() {
                                  if (isStart) {
                                    start = selected;
                                  } else {
                                    end = selected;
                                  }
                                  availabilityChanged = true;
                                  timesChanged = true;
                                });
                              }
                            },
                            child: Text(
                              '${isStart ? 'From' : 'To'} ${(isStart ? start : end).format(context)}',
                            ),
                          ),
                        ),
                    ],
                  ),
                if (widget.assignmentId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Unavailable dates'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (_) => RegistrationUnavailableDates(
                        assignmentId: widget.assignmentId!,
                      ),
                    ),
                  ),
                RegistrationButton(
                  'Done',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget fieldSection(
    String title,
    String description,
    List<ProviderRequirementField> sectionFields,
  ) => RegistrationSection(
    title,
    description,
    child: Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFD8DFEC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFD8DFEC)),
          ),
          constraints: const BoxConstraints(minHeight: 42),
        ),
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: .85),
      ),
      child: RegistrationPanel(
        padding: const EdgeInsets.all(12),
        child: RegistrationFields(
          compact: true,
          submissions: (values['submissions'] as List? ?? [])
              .whereType<Map>()
              .toList(),
          fields: sectionFields,
          allFields: [...widget.commonFields, ...widget.option.fields],
          values: fields,
          onChanged: () => setState(() {}),
        ),
      ),
    ),
  );

  String slotTime(int day, String key, TimeOfDay fallback) {
    if (timesChanged) return time(fallback);
    final previous =
        ((values['availability'] as Map?)?['weeklySlots'] as List? ?? [])
            .whereType<Map>()
            .where(
              (slot) =>
                  slot['dayOfWeek'] == RegistrationRepository.weekdays[day],
            )
            .firstOrNull;
    return previous?[key] as String? ?? time(fallback);
  }

  String time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  void save() {
    setState(() => error = null);
    if (!form.currentState!.validate()) return;
    if (widget.option.usesServiceAreas(widget.setup)) {
      if (locationModes.isEmpty) {
        setState(
          () => error = 'This service is missing its location configuration. Please reload the service.',
        );
        return;
      }
      var valid = true;
      for (final key in locationKeys.values) {
        if (key.currentState?.validate() != true) valid = false;
      }
      if (!valid) return;
    }
    if (widget.setup.availabilityEnabled && !anyDay && days.isEmpty) {
      setState(() => error = 'Select at least one day.');
      return;
    }
    if (!anyTime &&
        (start.hour * 60 + start.minute >= end.hour * 60 + end.minute)) {
      setState(() => error = 'Start time must be before end time.');
      return;
    }
    final result = <String, dynamic>{
      ...values,
      'fields': fields,
      if (widget.option.usesServiceAreas(widget.setup)) ...{
        'locationsByMode': {
          for (final entry in locationKeys.entries)
            entry.key: entry.value.currentState!.snapshot,
        },
        // Retain the legacy shape for existing single-mode drafts and callers.
        'deliveryMode': locationModes.length == 1 ? locationModes.single : null,
        'areas': locationModes.length == 1 && locationKeys.isNotEmpty
            ? locationKeys.values.single.currentState!.areas
            : <Map<String, dynamic>>[],
      },
      'availability': !availabilityChanged && values['availability'] != null
          ? values['availability']
          : {
              'availableAnyDay': anyDay,
              'availableAnyTime': anyTime,
              'weeklySlots': anyDay
                  ? []
                  : [
                      for (final day in days.toList()..sort())
                        {
                          'dayOfWeek': RegistrationRepository.weekdays[day],
                          'startTime': anyTime
                              ? null
                              : slotTime(day, 'startTime', start),
                          'endTime': anyTime
                              ? null
                              : slotTime(day, 'endTime', end),
                        },
                    ],
            },
      'saved': true,
    };
    if (widget.option.usesServiceAreas(widget.setup)) {
      final validation = widget.option.validateLocations(result);
      if (validation != null) {
        setState(() => error = validation);
        return;
      }
    }
    if (widget.onSave != null) {
      widget.onSave!(result);
    } else {
      Navigator.pop(context, result);
    }
  }

  Widget frame({required Widget child}) {
    if (widget.asSheet) {
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      );
    }
    return RegistrationPage(
      step: 2,
      firstStep: widget.firstStep,
      title: widget.isServiceUpdate ? 'Update Service' : 'Register a Service',
      showProgress: !widget.isServiceUpdate,
      onBack: widget.onBack ?? () => Navigator.pop(context),
      busy: widget.busy,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => frame(
    child: AbsorbPointer(
      absorbing: widget.busy,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: RegistrationOptionArtwork(option: widget.option),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      registrationText(widget.option.name, 20, bold: true),
                      registrationText(
                        widget.option.description ??
                            'Tell us about the service you offer',
                        11,
                        color: registrationMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (widget.option.usesServiceAreas(widget.setup)) ...[
              if (locationModes.isEmpty)
                const RegistrationNotice(
                  'This service is missing its location configuration. Please reload the service. If this continues, contact support.',
                  warning: true,
                ),
              for (final entry in locationKeys.entries)
                _ConfiguredLocationEditor(
                  key: entry.value,
                  option: widget.option,
                  mode: entry.key,
                  multiple: locationKeys.length > 1,
                  initial:
                      widget.option.locationGroups(values)[entry.key] ?? {},
                  assignmentId: widget.assignmentId,
                  loadSavedLocations: widget.loadSavedLocations,
                ),
              if (locationModes.length == 1 && locationModes.single == 'ONLINE')
                const RegistrationNotice(
                  'This service is provided online. No physical location is needed.',
                ),
            ],
            if (widget.setup.availabilityEnabled)
              RegistrationSection(
                'Weekly Availability',
                'Select the days you are available for this service.',
                trailing: IconButton(
                  tooltip: 'Availability settings',
                  constraints: const BoxConstraints.tightFor(
                    width: 16,
                    height: 16,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: availabilitySettings,
                  icon: const SizedBox(
                    width: 13,
                    height: 13,
                    child: RegistrationAsset('option_imgInformationIcon'),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final (i, day) in [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ].indexed) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Semantics(
                              toggled: anyDay || days.contains(i),
                              label: day,
                              child: InkWell(
                                onTap: () => setState(() {
                                  availabilityChanged = true;
                                  if (anyDay) {
                                    days = {0, 1, 2, 3, 4, 5, 6};
                                    anyDay = false;
                                  }
                                  if (!days.remove(i)) days.add(i);
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F9FA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      registrationText(day, 10),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: 33,
                                        height: 18.5,
                                        child: RegistrationAsset(
                                          (anyDay || days.contains(i))
                                              ? 'option_imgAvailabilitySwitch'
                                              : 'option_imgAvailabilitySwitch1',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            if (widget.option.fields.isNotEmpty)
              fieldSection(
                'Additional Information',
                'Additional details for ${widget.option.name}.',
                widget.option.fields,
              ),
            if (widget.saveError != null)
              RegistrationNotice(widget.saveError!, warning: true),
            if (error != null) ...[
              RegistrationNotice(error!, warning: true),
              const SizedBox(height: 12),
            ],
            RegistrationButton(
              'Save ${widget.option.name} Details',
              onPressed: widget.busy ? null : save,
            ),
          ],
        ),
      ),
    ),
  );
}
