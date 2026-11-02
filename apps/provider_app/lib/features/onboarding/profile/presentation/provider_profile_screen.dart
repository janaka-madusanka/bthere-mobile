import 'package:bthere_common/bthere_common.dart';

import '../../markets/application/provider_market_controller.dart';
import '../../markets/domain/provider_market.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/presentation/branded_form_page.dart';
import 'provider_profile_page.dart';
import '../application/provider_profile_controller.dart';
import '../domain/provider_profile_input.dart';

class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({
    super.key,
    this.onSaved,
    this.onBack,
    this.initialOnboarding = false,
    this.initialProfile,
  });
  final bool initialOnboarding;
  final Map<String, dynamic>? initialProfile;
  final VoidCallback? onSaved, onBack;
  @override
  ConsumerState<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends ConsumerState<ProviderProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(),
      _last = TextEditingController(),
      _bio = TextEditingController(),
      _dateText = TextEditingController();
  int? _marketId;
  DateTime? _date;
  ProviderGender? _gender;
  ProviderAvailability _availability = ProviderAvailability.available;
  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile == null) return;
    _first.text = profile['firstName'] as String? ?? '';
    _last.text = profile['lastName'] as String? ?? '';
    _bio.text = profile['bio'] as String? ?? '';
    _date = DateTime.tryParse(profile['dateOfBirth'] as String? ?? '');
    _dateText.text = profile['dateOfBirth'] as String? ?? '';
    _gender = ProviderGender.tryParse(profile['gender']);
    _marketId = profile['marketId'] as int?;
    _availability =
        ProviderAvailability.values
            .where((v) => v.wireValue == profile['availabilityStatus'])
            .firstOrNull ??
        ProviderAvailability.available;
  }

  @override
  void dispose() {
    for (final controller in [_first, _last, _bio, _dateText]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      builder: (context, child) => Theme(
        data:
            !widget.initialOnboarding &&
                Theme.of(context).brightness == Brightness.dark
            ? BThereTheme.dark()
            : BThereTheme.authentication(),
        child: child!,
      ),
      initialDate: _date ?? today,
      firstDate: DateTime(1),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select date of birth',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _date = selected;
      _dateText.text = MaterialLocalizations.of(context)
          .formatShortDate(selected);
    });
  }

  void _submit() {
    final markets = ref.read(providerMarketControllerProvider);
    final result = markets.asData?.value;
    if (markets.isLoading ||
        markets.hasError ||
        result is! Success<List<ProviderMarket>> ||
        !result.value.any(
          (market) => market.id == _marketId && market.status == 'ACTIVE',
        )) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref
        .read(providerProfileControllerProvider.notifier)
        .submit(
          ProviderProfileInput(
            marketId: _marketId!,
            firstName: _first.text,
            lastName: _last.text,
            bio: _bio.text,
            dateOfBirth: _date!,
            gender: _gender!,
            availabilityStatus: _availability,
            nicNumber: widget.initialProfile?['nicNumber'] as String?,
            passportNumber: widget.initialProfile?['passportNumber'] as String?,
            profilePhoto: widget.initialProfile?['profilePhoto'] as String?,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        !widget.initialOnboarding &&
            Theme.of(context).brightness == Brightness.dark
        ? BThereTheme.dark()
        : BThereTheme.authentication();
    final state = ref.watch(providerProfileControllerProvider);
    ref.listen(providerProfileControllerProvider, (_, next) {
      if (next.saved) widget.onSaved?.call();
    });
    final busy = state.loading || state.saved;
    final marketState = ref.watch(providerMarketControllerProvider);
    final marketResult = marketState.asData?.value;
    final markets =
        !marketState.isLoading &&
            !marketState.hasError &&
            marketResult is Success<List<ProviderMarket>>
        ? marketResult.value
              .where((market) => market.status == 'ACTIVE')
              .toList()
        : <ProviderMarket>[];
    final selectedMarket = markets.any((market) => market.id == _marketId)
        ? _marketId
        : null;
    final canSubmit = !busy && selectedMarket != null;
    Widget marketSelector() {
      if (marketState.isLoading) {
        return BThereFieldGroup(
          label: 'Market',
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.place_outlined),
            ),
            child: const BThereLoadingState(
              label: 'Loading markets…',
              compact: true,
            ),
          ),
        );
      }
      if (marketState.hasError ||
          marketResult is Failure<List<ProviderMarket>>) {
        return BThereFieldGroup(
          label: 'Market',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BThereInlineError(
                marketResult is Failure<List<ProviderMarket>>
                    ? marketResult.failure.message
                    : 'Unable to load markets. Please try again.',
              ),
              const SizedBox(height: 8),
              BThereButton(
                label: 'Retry markets',
                variant: BThereButtonVariant.outlined,
                onPressed: busy
                    ? null
                    : () => ref
                          .read(providerMarketControllerProvider.notifier)
                          .reload(),
              ),
            ],
          ),
        );
      }
      if (markets.isEmpty) {
        return const BThereFieldGroup(
          label: 'Market',
          child: InputDecorator(
            decoration: InputDecoration(prefixIcon: Icon(Icons.place_outlined)),
            child: Text('No markets are currently available.'),
          ),
        );
      }
      return BThereSelectorField<int>(
        key: const ValueKey('profile-market'),
        label: 'Market',
        value: selectedMarket,
        placeholder: 'Select your market',
        sheetTitle: 'Select market',
        icon: Icons.place_outlined,
        enabled: !busy,
        options: markets
            .map(
              (market) =>
                  BThereSelectorOption(value: market.id, label: market.name),
            )
            .toList(),
        onChanged: busy ? null : (value) => setState(() => _marketId = value),
        validator: (value) => value == null ? 'Select your market.' : null,
      );
    }

    Widget text(
      String label,
      TextEditingController controller, {
      bool required = false,
      Iterable<String>? autofillHints,
    }) => BThereTextField(
      label: label,
      labelPlacement: BThereFieldLabelPlacement.above,
      controller: controller,
      hint: label == 'First name'
          ? 'Enter your first name'
          : 'Enter your last name',
      prefix: const Icon(Icons.person_outline),
      enabled: !busy,
      autofillHints: autofillHints,
      textInputAction: TextInputAction.next,
      validator: required ? ProviderProfileInput.requiredText : null,
    );
    final form = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.initialOnboarding) ...[
            Text(
              'Complete your profile',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your personal details so we can set up your provider account.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: BThereSpacing.lg),
          ],
          text(
            'First name',
            _first,
            required: true,
            autofillHints: [AutofillHints.givenName],
          ),
          const SizedBox(height: 16),
          text(
            'Last name',
            _last,
            required: true,
            autofillHints: [AutofillHints.familyName],
          ),
          const SizedBox(height: 16),
          BThereFieldGroup(
            label: 'Date of birth',
            child: TextFormField(
              key: const ValueKey('profile-date-of-birth'),
              controller: _dateText,
              readOnly: true,
              enabled: !busy,
              onTap: busy ? null : _pickDate,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                hintText: 'Select your date of birth',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (_) =>
                  _date == null ? 'Select your date of birth.' : null,
            ),
          ),
          const SizedBox(height: 16),
          BThereSelectorField<ProviderGender>(
            key: const ValueKey('profile-gender'),
            label: 'Gender',
            value: _gender,
            placeholder: 'Select your gender',
            sheetTitle: 'Select gender',
            icon: Icons.person_outline,
            enabled: !busy,
            options: ProviderGender.values
                .map(
                  (value) =>
                      BThereSelectorOption(value: value, label: value.label),
                )
                .toList(),
            onChanged: busy ? null : (value) => setState(() => _gender = value),
            validator: (value) => value == null ? 'Select your gender.' : null,
          ),
          const SizedBox(height: 16),
          marketSelector(),
          const SizedBox(height: 16),
          if (!widget.initialOnboarding)
            BThereFieldGroup(
              label: 'Availability status',
              child: DropdownButtonFormField<ProviderAvailability>(
                key: const ValueKey('profile-availability'),
                initialValue: _availability,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                items: ProviderAvailability.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => setState(
                        () => _availability = value ?? _availability,
                      ),
                validator: (value) =>
                    value == null ? 'Select your availability.' : null,
              ),
            ),
          if (!widget.initialOnboarding)
            const SizedBox(height: BThereSpacing.md),
          BThereTextField(
            label: 'Bio (optional)',
            hint: 'Tell us a bit about yourself...',
            prefix: const Icon(Icons.notes_outlined),
            labelPlacement: BThereFieldLabelPlacement.above,
            controller: _bio,
            enabled: !busy,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          if (state.failure != null) ...[
            BThereInlineError(state.failure!.message),
            const SizedBox(height: 16),
          ],
          BTherePrimaryButton(
            label: widget.initialOnboarding ? 'Save profile' : 'Continue',
            onPressed: canSubmit ? _submit : null,
            loading: busy,
          ),
          if (widget.onBack != null) ...[
            const SizedBox(height: 12),
            BThereButton(
              label: 'Back to setup',
              variant: BThereButtonVariant.outlined,
              enabled: !busy,
              onPressed: widget.onBack,
            ),
          ],
        ],
      ),
    );
    return PopScope(
      canPop: !busy,
      child: widget.initialOnboarding
          ? BrandedFormPage(
              title: 'Provider Details',
              subtitle:
                  "We'll use this information to set up your Provider account.",
              child: form,
            )
          : ProviderProfilePage(child: form),
    );
  }
}
