part of 'provider_account_screen.dart';

class _GlobalProfileEditor extends StatefulWidget {
  const _GlobalProfileEditor({
    required this.section,
    required this.initial,
    required this.repository,
  });
  final String section;
  final ProfileSupplement? initial;
  final ProfileSupplementRepository repository;
  @override
  State<_GlobalProfileEditor> createState() => _GlobalProfileEditorState();
}

class _GlobalProfileEditorState extends State<_GlobalProfileEditor> {
  final form = GlobalKey<FormState>();
  final skillIds = <int>{}, languages = <String>{}, days = <String>{};
  final starts = <String, String>{}, ends = <String, String>{};
  late final TextEditingController method, bank, number, holder;
  bool anyTime = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    skillIds.addAll(value?.skills.map((s) => s.id) ?? <int>[]);
    languages.addAll(value?.languages ?? <String>[]);
    final hours = value?.workingHours;
    anyTime = hours?.availableAnyTime ?? true;
    if (hours?.availableAnyDay == true) {
      days.addAll(RegistrationRepository.weekdays);
    }
    for (final slot in hours?.slots ?? <ProfileDaySlot>[]) {
      days.add(slot.day);
      if (slot.start != null) starts[slot.day] = slot.start!;
      if (slot.end != null) ends[slot.day] = slot.end!;
    }
    method = TextEditingController(text: value?.payout?.method ?? '');
    bank = TextEditingController(text: value?.payout?.bankName ?? '');
    final accountNumber = value?.payout?.accountNumber ?? '';
    number = TextEditingController(
      text: RegExp(r'[•*]').hasMatch(accountNumber) ? '' : accountNumber,
    );
    holder = TextEditingController(text: value?.payout?.accountHolder ?? '');
  }

  @override
  void dispose() {
    method.dispose();
    bank.dispose();
    number.dispose();
    holder.dispose();
    super.dispose();
  }

  Future<void> _time(String day, bool start) async {
    final raw =
        (start ? starts : ends)[day] ?? (start ? '08:00:00' : '17:00:00');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(raw.substring(0, 2)),
        minute: int.parse(raw.substring(3, 5)),
      ),
    );
    if (value == null || !mounted) return;
    setState(
      () => (start ? starts : ends)[day] =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00',
    );
  }

  Future<void> _save() async {
    if (saving || widget.initial == null || !form.currentState!.validate()) {
      return;
    }
    if (widget.section == 'Availability' && days.isEmpty) {
      setState(() => error = 'Select at least one working day.');
      return;
    }
    if (widget.section == 'Availability' &&
        !anyTime &&
        days.any(
          (d) =>
              (starts[d] ?? '08:00:00').compareTo(ends[d] ?? '17:00:00') >= 0,
        )) {
      setState(() => error = 'Start time must be before end time.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final Result<void> result;
      switch (widget.section) {
        case 'Skills & Languages':
          result = await widget.repository.saveSkillsLanguages(
            skillIds.toList()..sort(),
            languages.toList()..sort(),
          );
        case 'Availability':
          final everyDay = days.length == 7 && anyTime;
          result = await widget.repository.saveWorkingHours(
            ProfileWorkingHours(
              availableAnyDay: everyDay,
              availableAnyTime: anyTime,
              slots: everyDay
                  ? []
                  : [
                      for (final day in RegistrationRepository.weekdays.where(
                        days.contains,
                      ))
                        ProfileDaySlot(
                          day,
                          anyTime ? null : starts[day] ?? '08:00:00',
                          anyTime ? null : ends[day] ?? '17:00:00',
                        ),
                    ],
            ),
          );
        default:
          result = await widget.repository.savePayout(
            ProfilePayout(
              method: method.text.trim(),
              bankName: bank.text.trim(),
              accountNumber: number.text.trim(),
              accountHolder: holder.text.trim(),
            ),
          );
      }
      if (!mounted) return;
      if (result is Success<void>) {
        Navigator.pop(context, true);
      } else {
        setState(
          () => error = 'Unable to save your changes. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to save your changes. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.section,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.initial == null) ...[
                const Text(
                  'These profile settings are not available yet. Please try again later.',
                ),
                const SizedBox(height: 20),
              ] else if (widget.section == 'Skills & Languages') ...[
                const Text(
                  'Skills',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (widget.initial!.skillCatalog.isEmpty)
                  const Text('No additional skills available.'),
                for (final skill in {
                  for (final skill in [
                    ...widget.initial!.skills,
                    ...widget.initial!.skillCatalog,
                  ])
                    skill.id: skill,
                }.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(skill.name),
                    value: skillIds.contains(skill.id),
                    onChanged: saving
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              skillIds.add(skill.id);
                            } else {
                              skillIds.remove(skill.id);
                            }
                          }),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Languages',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final language in ['ENGLISH', 'SINHALA', 'TAMIL'])
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_readable(language)),
                    value: languages.contains(language),
                    onChanged: saving
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              languages.add(language);
                            } else {
                              languages.remove(language);
                            }
                          }),
                  ),
              ] else if (widget.section == 'Availability') ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available any time'),
                  value: anyTime,
                  onChanged: saving ? null : (v) => setState(() => anyTime = v),
                ),
                for (final day in RegistrationRepository.weekdays)
                  Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_readable(day)),
                        value: days.contains(day),
                        onChanged: saving
                            ? null
                            : (v) => setState(() {
                                if (v == true) {
                                  days.add(day);
                                } else {
                                  days.remove(day);
                                }
                              }),
                      ),
                      if (days.contains(day) && !anyTime)
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: saving
                                    ? null
                                    : () => _time(day, true),
                                child: Text(
                                  'From ${(starts[day] ?? '08:00:00').substring(0, 5)}',
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: saving
                                    ? null
                                    : () => _time(day, false),
                                child: Text(
                                  'To ${(ends[day] ?? '17:00:00').substring(0, 5)}',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ] else ...[
                for (final field in [
                  ('Payment Method', method),
                  ('Bank Name', bank),
                  ('Account Number', number),
                  ('Account Holder Name', holder),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: field.$2,
                      enabled: !saving,
                      decoration: InputDecoration(labelText: field.$1),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'This field is required.'
                          : null,
                    ),
                  ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BThereInlineError(error!),
                ),
              BThereButton(
                label: 'Save changes',
                loading: saving,
                onPressed: widget.initial == null || saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
