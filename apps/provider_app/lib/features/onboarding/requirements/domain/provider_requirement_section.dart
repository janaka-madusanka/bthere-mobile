import '../../domain/provider_completion.dart';
import 'provider_onboarding_schema.dart';

enum ProviderRequirementSection {
  options('options', 'Service options'),
  documents('documents', 'Documents'),
  skills('skills', 'Skills'),
  certificates('certificates', 'Certificates'),
  education('education', 'Education'),
  availability('availability', 'Availability'),
  locations('locations', 'Service locations'),
  additional('additional', 'Additional information');

  const ProviderRequirementSection(this.slug, this.label);
  final String slug, label;
}

final class ProviderRequirementRow {
  const ProviderRequirementRow(this.section, this.completed, {this.level});
  final ProviderRequirementSection section;
  final bool completed;
  final ProviderRequirementLevel? level;
}

List<ProviderRequirementRow> requirementRows(
  ProviderOnboardingSchema schema,
  ProviderServiceCompletion service,
) {
  final s = schema.serviceSetup;
  return List.unmodifiable([
    if (s.optionsRequired || schema.options.isNotEmpty)
      ProviderRequirementRow(
        ProviderRequirementSection.options,
        service.optionsCompleted,
        level: s.optionsRequired
            ? ProviderRequirementLevel.required
            : ProviderRequirementLevel.optional,
      ),
    if (s.documents.isNotEmpty)
      ProviderRequirementRow(
        ProviderRequirementSection.documents,
        service.documentsCompleted,
      ),
    if (s.skills.isNotEmpty)
      ProviderRequirementRow(
        ProviderRequirementSection.skills,
        service.skillsCompleted,
      ),
    if (s.certificates.level != ProviderRequirementLevel.disabled)
      ProviderRequirementRow(
        ProviderRequirementSection.certificates,
        service.certificatesCompleted,
        level: s.certificates.level,
      ),
    if (s.education.level != ProviderRequirementLevel.disabled)
      ProviderRequirementRow(
        ProviderRequirementSection.education,
        service.educationCompleted,
        level: s.education.level,
      ),
    if (s.availabilityEnabled)
      ProviderRequirementRow(
        ProviderRequirementSection.availability,
        service.availabilityCompleted,
      ),
    if (s.serviceAreasEnabled)
      ProviderRequirementRow(
        ProviderRequirementSection.locations,
        service.serviceAreasCompleted,
      ),
    if (schema.commonFields.isNotEmpty ||
        schema.options.any((o) => o.fields.isNotEmpty))
      ProviderRequirementRow(
        ProviderRequirementSection.additional,
        service.customRequirementsCompleted,
      ),
  ]);
}

bool serviceNeedsWork(ProviderServiceCompletion s) =>
    !s.documentsCompleted ||
    !s.skillsCompleted ||
    !s.certificatesCompleted ||
    !s.educationCompleted ||
    !s.availabilityCompleted ||
    !s.serviceAreasCompleted ||
    !s.optionsCompleted ||
    !s.customRequirementsCompleted;
