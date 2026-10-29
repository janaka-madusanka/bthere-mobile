import '../../../app/customer_theme.dart';

import 'dart:typed_data';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../../auth/presentation/customer_brand_image.dart';
import '../application/customer_profile_controller.dart';
import '../data/customer_photo_upload.dart';
import '../domain/customer_profile.dart';
import 'customer_profile_photo.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});
  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  String? _photo, _photoError;
  bool _initialized = false, _uploading = false;
  static const _labels = {
    'firstName': 'First name',
    'lastName': 'Last name',
    'addressLine1': 'Address line 1',
    'addressLine2': 'Address line 2',
    'city': 'City',
    'district': 'District',
    'province': 'Province',
    'postalCode': 'Postal code',
    'country': 'Country',
  };
  static const _required = {
    'firstName',
    'lastName',
    'addressLine1',
    'city',
    'country',
  };
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _photoError = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (file == null || !mounted) return;
      final length = await file.length();
      if (length != null && (length <= 0 || length > 10 * 1024 * 1024)) {
        throw const CustomerAuthFailure(
          'Choose a profile photo no larger than 10 MB.',
        );
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (builder.length + chunk.length > 10 * 1024 * 1024) {
          throw const CustomerAuthFailure(
            'Choose a profile photo no larger than 10 MB.',
          );
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (!mounted) return;
      final url = await uploadCustomerPhoto(
        ref.read(customerAuthServiceProvider),
        bytes,
        file.name,
      );
      if (mounted) {
        setState(() {
          _photo = url;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _photoError = error is CustomerAuthFailure
              ? error.message
              : 'Unable to upload your photo. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(customerProfileControllerProvider);
    final auth = ref.watch(customerAuthControllerProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, auth]),
      builder: (context, _) {
        if (!_initialized) {
          final values = controller.profile?.details.toJson();
          for (final key in _labels.keys) {
            _fields[key] = TextEditingController(
              text: values?[key] as String? ?? '',
            );
          }
          _photo = controller.profile?.details.profilePhoto;
          _initialized = true;
        }
        final busy = controller.saving || _uploading || auth.busy;
        final editing = controller.profile?.profileCompleted == true;
        Future<void> save() async {
          if (busy || !_form.currentState!.validate()) return;
          FocusScope.of(context).unfocus();
          String text(String key) => _fields[key]!.text;
          await controller.save(
            CustomerProfileInput(
              firstName: text('firstName'),
              lastName: text('lastName'),
              addressLine1: text('addressLine1'),
              city: text('city'),
              country: text('country'),
              addressLine2: text('addressLine2'),
              district: text('district'),
              province: text('province'),
              postalCode: text('postalCode'),
              profilePhoto: _photo,
            ),
          );
          if (context.mounted &&
              controller.stage == CustomerProfileStage.ready &&
              controller.error == null) {
            context.go(editing ? '/account' : '/market');
          }
        }

        Widget field(String name) => BThereTextField(
          key: ValueKey('customer-profile-$name'),
          label:
              '${_labels[name]}${name == 'addressLine2' ? ' (optional)' : ''}',
          labelPlacement: BThereFieldLabelPlacement.above,
          controller: _fields[name],
          enabled: !busy,
          hint: switch (name) {
            'firstName' => 'Your first name',
            'lastName' => 'Your last name',
            'addressLine1' => 'House number, street name, etc.',
            'addressLine2' => 'Apartment, unit, building, etc.',
            'city' => 'Enter your city',
            'district' => 'Enter district',
            'province' => 'Enter province',
            'postalCode' => 'Postal code',
            _ => 'Enter country',
          },
          prefix: Icon(switch (name) {
            'firstName' || 'lastName' => Icons.person_outline,
            'addressLine1' || 'addressLine2' => Icons.location_on_outlined,
            'city' => Icons.location_city_outlined,
            'district' || 'province' => Icons.map_outlined,
            'postalCode' => Icons.view_week_outlined,
            _ => Icons.public_outlined,
          }, size: 23),
          autofillHints: switch (name) {
            'firstName' => const [AutofillHints.givenName],
            'lastName' => const [AutofillHints.familyName],
            'addressLine1' => const [AutofillHints.streetAddressLine1],
            'addressLine2' => const [AutofillHints.streetAddressLine2],
            'city' => const [AutofillHints.addressCity],
            'postalCode' => const [AutofillHints.postalCode],
            'country' => const [AutofillHints.countryName],
            _ => null,
          },
          textInputAction: name == 'country'
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted: name == 'country' ? (_) => save() : null,
          validator: (value) {
            final text = (value ?? '').trim();
            final max = switch (name) {
              'addressLine1' || 'addressLine2' => 255,
              'postalCode' => 20,
              _ => 100,
            };
            if (_required.contains(name) && text.isEmpty) {
              return 'Enter your ${_labels[name]!.toLowerCase()}.';
            }
            return text.runes.length > max
                ? 'Use at most $max characters.'
                : null;
          },
        );
        Widget pair(String first, String second) => LayoutBuilder(
          builder: (context, bounds) {
            if (bounds.maxWidth < 310 ||
                MediaQuery.textScalerOf(context).scale(16) > 21) {
              return Column(
                children: [
                  field(first),
                  const SizedBox(height: 16),
                  field(second),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field(first)),
                const SizedBox(width: 14),
                Expanded(child: field(second)),
              ],
            );
          },
        );
        final base = CustomerTheme.authentication();
        final theme = base.copyWith(
          scaffoldBackgroundColor: const Color(0xFFF8FAFB),
          textTheme: base.textTheme.copyWith(
            labelMedium: base.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0B3037),
            ),
          ),
          inputDecorationTheme: base.inputDecorationTheme.copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            hintStyle: base.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8997A0),
              fontSize: 14,
            ),
            prefixIconColor: const Color(0xFF687B83),
            filled: true,
            fillColor: const Color(0xCCFFFFFF),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6EDF0)),
            ),
          ),
        );
        return Theme(
          data: theme,
          child: PopScope(
            canPop: !busy,
            child: Scaffold(
              body: BThereBrandedBackground(
                child: SafeArea(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        key: const ValueKey('customer-profile-form'),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Form(
                              key: _form,
                              child: AutofillGroup(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Center(
                                      child: BThereBrandImage(
                                        asset: BThereBrandAsset.carePromise,
                                        width: 155,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        editing
                                            ? 'Edit your profile'
                                            : 'Let’s get to know you',
                                        key: const ValueKey(
                                          'customer-profile-heading',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: base.textTheme.headlineMedium
                                            ?.copyWith(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0B3037),
                                              height: 1.2,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Complete your profile so we can\npersonalize your experience.',
                                      textAlign: TextAlign.center,
                                      style: base.textTheme.bodyLarge?.copyWith(
                                        fontSize: 14,
                                        height: 1.45,
                                        color: const Color(0xFF687B83),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    CustomerProfilePhoto(
                                      url: _photo,
                                      uploading: _uploading,
                                      enabled: !busy,
                                      onPick: _pickPhoto,
                                      onRemove: () => setState(() {
                                        _photo = null;
                                        _photoError = null;
                                      }),
                                    ),
                                    if (_photoError case final error?)
                                      BThereInlineError(error),
                                    const SizedBox(height: 20),
                                    pair('firstName', 'lastName'),
                                    const SizedBox(height: 16),
                                    field('addressLine1'),
                                    const SizedBox(height: 16),
                                    field('addressLine2'),
                                    const SizedBox(height: 16),
                                    pair('city', 'district'),
                                    const SizedBox(height: 16),
                                    pair('province', 'postalCode'),
                                    const SizedBox(height: 16),
                                    field('country'),
                                    const SizedBox(height: 24),
                                    if (controller.error case final error?) ...[
                                      BThereInlineError(error),
                                      const SizedBox(height: 16),
                                    ],
                                    if (auth.error case final error?) ...[
                                      BThereInlineError(error),
                                      const SizedBox(height: 16),
                                    ],
                                    BTherePrimaryButton(
                                      key: const ValueKey(
                                        'customer-profile-save',
                                      ),
                                      label: editing
                                          ? 'Save changes'
                                          : 'Save and continue',
                                      loading: controller.saving,
                                      onPressed: busy ? null : save,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          tooltip: editing ? 'Back to account' : 'Sign out',
                          onPressed: busy
                              ? null
                              : editing
                              ? () => context.go('/account')
                              : auth.logout,
                          icon: Icon(
                            editing ? Icons.close : Icons.logout,
                            size: 20,
                            color: const Color(0xFF687B83),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
