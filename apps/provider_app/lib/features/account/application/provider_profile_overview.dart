import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/documents/documents_controller.dart';
import '../../services/documents/document_models.dart';
import '../../services/application/service_providers.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/requirements/options/domain/provider_selected_option.dart';
import '../../../app/providers/app_providers.dart';

final profileDocumentsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(documentsRepositoryProvider).documents(),
  dependencies: [documentsRepositoryProvider],
);

class ProfileSkill {
  const ProfileSkill(this.id, this.name);
  final int id;
  final String name;
}

class ProfileWorkingHours {
  const ProfileWorkingHours({
    required this.availableAnyDay,
    required this.availableAnyTime,
    required this.slots,
  });
  final bool availableAnyDay, availableAnyTime;
  final List<ProfileDaySlot> slots;
}

class ProfileDaySlot {
  const ProfileDaySlot(this.day, this.start, this.end);
  final String day;
  final String? start, end;
}

class ProfilePayout {
  const ProfilePayout({
    required this.method,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
  });
  final String method, bankName, accountNumber, accountHolder;
}

/// Global settings requested for Profile. No service-assignment IDs belong here.
/// The supplied API only specifies assignment-scoped settings. The backend adapter
/// must be supplied once the global contract is confirmed; never guess endpoints.
class ProfileSupplement {
  const ProfileSupplement({
    this.completedBookings,
    this.city,
    this.country,
    this.skills = const [],
    this.skillCatalog = const [],
    this.languages = const [],
    this.workingHours,
    this.payout,
  });
  final int? completedBookings;
  final String? city, country;
  final List<ProfileSkill> skills, skillCatalog;
  final List<String> languages;
  final ProfileWorkingHours? workingHours;
  final ProfilePayout? payout;
}

abstract interface class ProfileSupplementRepository {
  Future<Result<ProfileSupplement>> load();
  Future<Result<void>> saveSkillsLanguages(
    List<int> skillIds,
    List<String> languages,
  );
  Future<Result<void>> saveWorkingHours(ProfileWorkingHours value);
  Future<Result<void>> savePayout(ProfilePayout value);
}

final profileSupplementRepositoryProvider =
    Provider<ProfileSupplementRepository>(
      (ref) => const _MissingProfileContract(),
    );
final profileSupplementProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(profileSupplementRepositoryProvider).load(),
  dependencies: [profileSupplementRepositoryProvider],
);

class _MissingProfileContract implements ProfileSupplementRepository {
  const _MissingProfileContract();
  Result<T> missing<T>() => const Failure(
    AppFailure(
      message: 'These profile settings are not available yet.',
      code: 'PROFILE_CONTRACT_REQUIRED',
    ),
  );
  @override
  Future<Result<ProfileSupplement>> load() async => missing();
  @override
  Future<Result<void>> saveSkillsLanguages(
    List<int> skillIds,
    List<String> languages,
  ) async => missing();
  @override
  Future<Result<void>> saveWorkingHours(ProfileWorkingHours value) async =>
      missing();
  @override
  Future<Result<void>> savePayout(ProfilePayout value) async => missing();
}

// Document requirements stay service/option specific; uploaded documents are
// shared. Merge only applicable requirements and retain the editor's context.

class ProfileDocumentRequirement {
  const ProfileDocumentRequirement(this.serviceTypeId, this.requirement);
  final int serviceTypeId;
  final DocumentRequirement requirement;
}

final profileDocumentRequirementsProvider =
    FutureProvider.autoDispose<Result<List<ProfileDocumentRequirement>>>(
      (ref) async {
        try {
          final assignments = await ref.watch(
            providerAssignmentsProvider.future,
          );
          if (assignments is! Success<List<ProviderServiceAssignment>>) {
            throw const FormatException();
          }
          final documents = ref.watch(documentsRepositoryProvider);
          final options = ref.watch(providerOptionsRepositoryProvider);
          final groups = await Future.wait(
            assignments.value.map((service) async {
              final result = await documents.requirements(
                service.providerTypeId,
              );
              if (result is! Success<List<DocumentRequirement>>) {
                throw const FormatException();
              }
              final needsOptions = result.value.any((r) => r.optionId != null);
              final selected = <int>{};
              if (needsOptions) {
                final selections = await options.loadSelections(
                  service.assignmentId,
                );
                if (selections is! Success<List<ProviderSelectedOption>>) {
                  throw const FormatException();
                }
                selected.addAll(
                  selections.value
                      .where(
                        (s) =>
                            s.providerStatus == 'ACTIVE' &&
                            s.adminStatus != 'INACTIVE',
                      )
                      .map((s) => s.optionId),
                );
              }
              return result.value
                  .where(
                    (r) => r.optionId == null || selected.contains(r.optionId),
                  )
                  .map(
                    (r) =>
                        ProfileDocumentRequirement(service.providerTypeId, r),
                  )
                  .toList();
            }),
          );
          final merged = <int, ProfileDocumentRequirement>{};
          for (final entry in groups.expand((g) => g)) {
            final previous = merged[entry.requirement.id];
            if (previous == null ||
                (!previous.requirement.required &&
                    entry.requirement.required)) {
              merged[entry.requirement.id] = entry;
            }
          }
          return Success(merged.values.toList());
        } catch (_) {
          return const Failure(
            AppFailure(
              message: 'Unable to load document requirements. Please retry.',
            ),
          );
        }
      },
      dependencies: [
        providerAssignmentsProvider,
        documentsRepositoryProvider,
        providerOptionsRepositoryProvider,
      ],
    );

final profileDocumentUrlProvider = FutureProvider.autoDispose
    .family<Result<Uri>, String>(
      (ref, key) => ref.watch(documentsRepositoryProvider).viewUrl(key),
      dependencies: [documentsRepositoryProvider],
    );
