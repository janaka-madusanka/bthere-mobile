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

class RegistrationOptionEditor extends ConsumerStatefulWidget {
  const RegistrationOptionEditor({
    required this.option,
    required this.service,
    required this.setup,
    required this.initial,
    this.commonFields = const [],
    this.assignmentId,
    super.key,
  });
  final ProviderSchemaOption option;
  final ProviderServiceType service;
  final ProviderServiceSetup setup;
  final List<ProviderRequirementField> commonFields;
  final int? assignmentId;
  final Map<String, dynamic> initial;
  @override
  ConsumerState<RegistrationOptionEditor> createState() => _OptionState();
}

class _OptionState extends ConsumerState<RegistrationOptionEditor> {
  final form = GlobalKey<FormState>();
  late Map<String, dynamic> values, fields;
  late List<Map<String, dynamic>> areas;
  late Set<int> days;
  String? mode, error;
  Map<String, dynamic>? pendingArea;
  final radiusInput = TextEditingController();
  bool anyTime = true, anyDay = false;
  bool loadingAreas = false;
  bool areasLoaded = true;
  bool availabilityChanged = false;
  bool timesChanged = false;
  int areaGeneration = 0;
  TimeOfDay start = const TimeOfDay(hour: 8, minute: 0),
      end = const TimeOfDay(hour: 17, minute: 0);
  @override
  void initState() {
    super.initState();
    values = Map.of(widget.initial);
    fields = Map<String, dynamic>.from(values['fields'] as Map? ?? {});
    areas = (values['areas'] as List? ?? [])
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
    mode = values['deliveryMode'] as String?;
    if (widget.option.deliveryModes.isNotEmpty &&
        !widget.option.deliveryModes.contains(mode)) {
      mode = widget.option.deliveryModes.length == 1
          ? widget.option.deliveryModes.single
          : null;
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
    if (areas.isEmpty &&
        mode != null &&
        mode != 'ONLINE' &&
        widget.assignmentId != null) {
      areasLoaded = false;
      Future.microtask(loadAreas);
    }
  }

  @override
  void dispose() {
    radiusInput.dispose();
    super.dispose();
  }

  Future<void> loadAreas() async {
    if (widget.assignmentId == null || mode == null || mode == 'ONLINE') return;
    final requestedMode = mode!;
    final request = ++areaGeneration;
    setState(() {
      loadingAreas = true;
      areasLoaded = false;
      error = null;
    });
    final result = await ref
        .read(registrationRepositoryProvider)
        .areas(widget.assignmentId!, widget.option.optionId, requestedMode);
    if (!mounted || mode != requestedMode || request != areaGeneration) return;
    setState(() {
      loadingAreas = false;
      if (result is Success<List<Map<String, dynamic>>>) {
        areas = result.value;
        areasLoaded = true;
      } else {
        error = 'Unable to load saved locations for this delivery mode. Please retry.';
      }
    });
  }

  Future<void> location({int? index, bool stage = false}) async {
    if (mode == null) {
      setState(() => error = 'Choose a delivery mode first.');
      return;
    }
    final result = await showRegistrationLocation(
      context,
      initial: index == null
          ? {'radiusKm': num.tryParse(radiusInput.text)}
          : areas[index],
      mode: mode!,
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null && stage) {
          pendingArea = result;
          radiusInput.text = result['radiusKm']?.toString() ?? '';
        } else if (index == null) {
          areas.add(result);
        } else {
          areas[index] = result;
        }
      });
    }
  }

  void addPendingArea() {
    if (pendingArea == null) {
      location(stage: true);
      return;
    }
    final radius = num.tryParse(radiusInput.text);
    if (mode == 'PROVIDER_TO_CUSTOMER' &&
        (radius == null || !radius.isFinite || radius <= 0)) {
      setState(() => error = 'Enter a positive service radius.');
      return;
    }
    setState(() {
      areas.add({
        ...pendingArea!,
        'radiusKm': mode == 'PROVIDER_TO_CUSTOMER' ? radius : null,
      });
      pendingArea = null;
      error = null;
    });
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

  List<ProviderRequirementField> get experienceFields => widget.option.fields
      .where(
        (field) =>
            field.code.toLowerCase().contains('experience') ||
            field.label.toLowerCase().contains('experience'),
      )
      .toList();

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
    if (widget.assignmentId != null &&
        mode != null &&
        mode != 'ONLINE' &&
        !areasLoaded) {
      setState(
        () => error = 'Load your saved locations before replacing them.',
      );
      return;
    }
    if (!form.currentState!.validate()) return;
    if (pendingArea != null) {
      setState(
        () => error = 'Tap + to add your selected location before saving.',
      );
      return;
    }
    if (widget.setup.serviceAreasEnabled &&
        (mode == null ||
            (widget.option.deliveryModes.isNotEmpty &&
                !widget.option.deliveryModes.contains(mode)))) {
      setState(() => error = 'Select a delivery mode.');
      return;
    }
    if (widget.setup.serviceAreasEnabled && mode != 'ONLINE' && areas.isEmpty) {
      setState(() => error = 'Add at least one service location.');
      return;
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
    Navigator.pop(context, <String, dynamic>{
      ...values,
      'fields': fields,
      'areas': areas,
      'deliveryMode': mode,
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
    });
  }

  @override
  Widget build(BuildContext context) => RegistrationPage(
    step: 2,
    onBack: () => Navigator.pop(context),
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
                child: widget.option.icon?.usableUri != null
                    ? RegistrationOptionArtwork(option: widget.option)
                    : widget.option.name.toLowerCase().contains('elder')
                    ? const RegistrationAsset('option_imgElderlyCareSymbol')
                    : RegistrationOptionSymbol(widget.option.name),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    registrationText(widget.option.name, 20, bold: true),
                    registrationText(
                      widget.option.description ??
                          'Tell us about the support you offer',
                      11,
                      color: registrationMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (experienceFields.isNotEmpty)
            fieldSection(
              'Experience',
              'Your experience in ${widget.option.name.toLowerCase()}.',
              experienceFields,
            ),
          if (widget.setup.serviceAreasEnabled)
            RegistrationSection(
              'Service Location & Area',
              'Where do you provide this service?',
              trailing: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: mode == null || mode == 'ONLINE'
                    ? null
                    : () => showRegistrationAreas(context, areas, mode!),
                child: registrationText(
                  'View in Map',
                  11,
                  color: const Color(0xFF168EFF),
                ),
              ),
              child: RegistrationPanel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.option.deliveryModes.length != 1) ...[
                      DropdownButtonFormField<String>(
                        initialValue: mode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Delivery mode',
                          isDense: true,
                        ),
                        items: [
                          for (final entry in const {
                            'PROVIDER_TO_CUSTOMER': 'I travel to the customer',
                            'CUSTOMER_TO_PROVIDER':
                                'Customers visit my location',
                            'ONLINE': 'Online',
                          }.entries)
                            if (widget.option.deliveryModes.isEmpty ||
                                widget.option.deliveryModes.contains(entry.key))
                              DropdownMenuItem(
                                value: entry.key,
                                child: registrationText(entry.value, 12),
                              ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            mode = value;
                            areas = [];
                            pendingArea = null;
                            loadingAreas = false;
                          });
                          loadAreas();
                        },
                        validator: (value) =>
                            value == null ? 'Select a delivery mode.' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (loadingAreas) const LinearProgressIndicator(),
                    if (mode != 'ONLINE') ...[
                      for (final (index, area) in areas.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: RegistrationPanel(
                            padding: const EdgeInsets.only(left: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: loadingAreas
                                        ? null
                                        : () => location(index: index),
                                    child: registrationText(
                                      '${area['locationName'] ?? area['city'] ?? ''}',
                                      12,
                                    ),
                                  ),
                                ),
                                if (mode == 'PROVIDER_TO_CUSTOMER' &&
                                    area['radiusKm'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F1F8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: registrationText(
                                      'Radius: ${area['radiusKm']} km',
                                      9,
                                      color: registrationMuted,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Remove location',
                                  onPressed: loadingAreas
                                      ? null
                                      : () => setState(
                                          () => areas.removeAt(index),
                                        ),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (areas.isNotEmpty)
                        const Center(
                          child: SizedBox(
                            width: 110,
                            child: Divider(height: 14, thickness: .6),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: loadingAreas || mode == null
                                  ? null
                                  : () => location(stage: true),
                              icon: const SizedBox(
                                width: 20,
                                height: 20,
                                child: RegistrationAsset(
                                  'option_imgLocationPin',
                                ),
                              ),
                              label: Row(
                                children: [
                                  Expanded(
                                    child: registrationText(
                                      pendingArea?['locationName'] as String? ??
                                          'Select Location',
                                      11,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 17,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (mode == 'PROVIDER_TO_CUSTOMER') ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 88,
                              child: TextFormField(
                                controller: radiusInput,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 12),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  hintText: 'km',
                                  suffixText: radiusInput.text.isNotEmpty
                                      ? 'km'
                                      : null,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 42,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: loadingAreas ? null : addPendingArea,
                              child: const Icon(
                                Icons.add,
                                color: registrationTeal,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      registrationText(
                        'This service is provided online.',
                        12,
                        color: registrationMuted,
                      ),
                  ],
                ),
              ),
            ),
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
          if (widget.option.fields.any(
            (field) => !experienceFields.contains(field),
          ))
            fieldSection(
              'Additional Information',
              'Additional details for ${widget.option.name.toLowerCase()}.',
              widget.option.fields
                  .where((field) => !experienceFields.contains(field))
                  .toList(),
            ),
          if (error != null) ...[
            RegistrationNotice(error!, warning: true),
            if (!areasLoaded && !loadingAreas)
              TextButton(
                onPressed: loadAreas,
                child: const Text('Retry loading locations'),
              ),
            const SizedBox(height: 12),
          ],
          RegistrationButton(
            'Save ${widget.option.name} Details',
            onPressed: loadingAreas ? null : save,
          ),
        ],
      ),
    ),
  );
}
