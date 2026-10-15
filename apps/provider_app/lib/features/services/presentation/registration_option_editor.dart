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
  bool anyTime = true, anyDay = false;
  bool loadingAreas = false;
  bool areasLoaded = true;
  bool availabilityChanged = false;
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

  Future<void> loadAreas() async {
    if (widget.assignmentId == null || mode == null || mode == 'ONLINE') return;
    final requestedMode = mode!;
    setState(() {
      loadingAreas = true;
      areasLoaded = false;
      error = null;
    });
    final result = await ref
        .read(registrationRepositoryProvider)
        .areas(widget.assignmentId!, widget.option.optionId, requestedMode);
    if (!mounted || mode != requestedMode) return;
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

  Future<void> location({int? index}) async {
    if (mode == null) {
      setState(() => error = 'Choose a delivery mode first.');
      return;
    }
    final result = await showRegistrationLocation(
      context,
      initial: index == null ? null : areas[index],
      mode: mode!,
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          areas.add(result);
        } else {
          areas[index] = result;
        }
      });
    }
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
    if (widget.setup.serviceAreasEnabled && mode == null) {
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
                          'startTime': anyTime ? null : time(start),
                          'endTime': anyTime ? null : time(end),
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
                child: widget.option.name.toLowerCase().contains('elder')
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
          if (widget.option.fields.isNotEmpty)
            RegistrationSection(
              'Experience & Additional Information',
              'Complete the details for this service.',
              child: RegistrationPanel(
                child: RegistrationFields(
                  submissions: (values['submissions'] as List? ?? [])
                      .whereType<Map>()
                      .toList(),
                  fields: widget.option.fields,
                  allFields: [...widget.commonFields, ...widget.option.fields],
                  values: fields,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          if (widget.setup.serviceAreasEnabled)
            RegistrationSection(
              'Service Location & Area',
              'Where do you provide this service?',
              child: RegistrationPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Delivery mode',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PROVIDER_TO_CUSTOMER',
                          child: Text('I travel to the customer'),
                        ),
                        DropdownMenuItem(
                          value: 'CUSTOMER_TO_PROVIDER',
                          child: Text('Customers visit my location'),
                        ),
                        DropdownMenuItem(
                          value: 'ONLINE',
                          child: Text('Online'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          mode = v;
                          areas = [];
                          loadingAreas = false;
                        });
                        loadAreas();
                      },
                      validator: (v) =>
                          v == null ? 'Select a delivery mode.' : null,
                    ),
                    const SizedBox(height: 12),
                    if (mode != 'ONLINE') ...[
                      for (final (i, area) in areas.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RegistrationPanel(
                            padding: const EdgeInsets.only(left: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => location(index: i),
                                    child: registrationText(
                                      '${area['locationName']}',
                                      12,
                                    ),
                                  ),
                                ),
                                if (area['radiusKm'] != null)
                                  registrationText(
                                    'Radius: ${area['radiusKm']} km',
                                    10,
                                    color: registrationMuted,
                                  ),
                                IconButton(
                                  tooltip: 'Remove location',
                                  onPressed: () =>
                                      setState(() => areas.removeAt(i)),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => location(),
                        icon: const Icon(
                          Icons.add_location_alt_outlined,
                          size: 20,
                        ),
                        label: const Text('Select Location'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (widget.setup.availabilityEnabled)
            RegistrationSection(
              'Weekly Availability',
              'Availability is shared across this service’s options.',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: registrationText('Available every day', 12),
                    value: anyDay,
                    onChanged: (v) => setState(() {
                      anyDay = v;
                      if (v) anyTime = true;
                      availabilityChanged = true;
                    }),
                  ),
                  if (!anyDay)
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
                              toggled: days.contains(i),
                              label: day,
                              child: InkWell(
                                onTap: () => setState(() {
                                  availabilityChanged = true;
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
                                      Container(
                                        width: 31,
                                        height: 17,
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: days.contains(i)
                                              ? registrationTeal
                                              : const Color(0xFFA0A6BC),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        alignment: days.contains(i)
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          width: 13,
                                          height: 13,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: registrationText('Available all day', 12),
                    value: anyTime,
                    onChanged: anyDay
                        ? null
                        : (v) => setState(() {
                            anyTime = v;
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
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: isStart ? start : end,
                                );
                                if (t != null && mounted) {
                                  setState(() {
                                    if (isStart) {
                                      start = t;
                                      availabilityChanged = true;
                                    } else {
                                      end = t;
                                      availabilityChanged = true;
                                    }
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
                ],
              ),
            ),
          if (widget.setup.availabilityEnabled && widget.assignmentId != null)
            TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (_) => RegistrationUnavailableDates(
                  assignmentId: widget.assignmentId!,
                ),
              ),
              icon: const Icon(Icons.event_busy_outlined, size: 18),
              label: const Text('Unavailable dates'),
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
