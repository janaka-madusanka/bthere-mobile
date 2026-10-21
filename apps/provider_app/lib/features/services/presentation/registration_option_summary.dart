import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../application/registration_payload.dart';
import 'registration_widgets.dart';

Color registrationOptionSurface(ProviderSchemaOption option) {
  return const Color(0xFFF0FCFF);
}

class RegistrationOptionArtwork extends StatelessWidget {
  const RegistrationOptionArtwork({required this.option, super.key});
  final ProviderSchemaOption option;
  @override
  Widget build(BuildContext context) {
    final uri = option.icon?.usableUri;
    final fallback = RegistrationOptionSymbol(option.name);
    if (uri == null) return fallback;
    return uri.path.toLowerCase().endsWith('.svg')
        ? SvgPicture.network(
            uri.toString(),
            fit: BoxFit.contain,
            semanticsLabel: option.icon?.altText ?? option.name,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.network(
            uri.toString(),
            fit: BoxFit.contain,
            semanticLabel: option.icon?.altText ?? option.name,
            errorBuilder: (_, _, _) => fallback,
          );
  }
}

/// Setup progress is calculated from answers, never from the editor's saved flag.
/// Approval remains owned by the server and is distinct from form completion.
class RegistrationOptionSummary extends StatelessWidget {
  const RegistrationOptionSummary({
    required this.option,
    required this.schema,
    required this.selected,
    required this.draft,
    required this.experience,
    required this.expanded,
    required this.onToggle,
    required this.onRemove,
    required this.onEdit,
    required this.onSkills,
    required this.onExperience,
    super.key,
  });
  final ProviderSchemaOption option;
  final ProviderOnboardingSchema schema;
  final Set<int> selected;
  final Map<String, dynamic> draft;
  final String experience;
  final bool expanded;
  final VoidCallback onToggle, onRemove, onEdit, onSkills, onExperience;

  @override
  Widget build(BuildContext context) {
    final fields = activeRegistrationFields(schema, selected);
    final answers = registrationAnswers(draft, selected: selected);
    final applicable = fields
        .where((field) => field.optionIds.contains(option.optionId))
        .toList();
    final additionalFields = applicable;
    bool answered(List<ProviderRequirementField> group) => group.every((field) {
      final visible = registrationFieldVisible(field, answers, fields);
      if (visible == null) return false;
      if (!visible) return true;
      final answer = answers['${field.fieldId}'];
      return validateRegistrationAnswer(field, answer) == null &&
          (!field.required || answer != null);
    });
    bool hasAnswer(List<ProviderRequirementField> group) => group.any((field) {
      final answer = answers['${field.fieldId}'];
      return answer != null &&
          answer != '' &&
          !(answer is List && answer.isEmpty);
    });
    final chosenSkills = registrationSkillIds(schema, draft);
    final configuredSkills = schema.serviceSetup.skills;
    final skillCount = configuredSkills
        .where((skill) => chosenSkills.contains(skill.metadata['skillId']))
        .length;
    final skillsComplete = configuredSkills
        .where((skill) => skill.metadata['required'] == true)
        .every((skill) => chosenSkills.contains(skill.metadata['skillId']));
    final optionData =
        (draft['options'] as Map? ?? {})['${option.optionId}'] as Map? ?? {};
    final modes = option.configuredLocationModes(optionData['deliveryMode']);
    final onlineOnly = modes.length == 1 && modes.single == 'ONLINE';
    final locationComplete =
        !option.usesServiceAreas(schema.serviceSetup) ||
        option.validateLocations(optionData) == null;
    final years = double.tryParse(experience);
    final experienceComplete = years != null && years.isFinite && years >= 0;
    final additionalComplete = answered(additionalFields);
    final availability = draft['availability'] as Map?;
    final availabilityComplete =
        !schema.serviceSetup.availabilityEnabled ||
        availability != null &&
            (availability['availableAnyDay'] == true ||
                (availability['weeklySlots'] as List? ?? []).isNotEmpty);
    final complete =
        availabilityComplete &&
        experienceComplete &&
        skillsComplete &&
        locationComplete &&
        additionalComplete;
    const green = Color(0xFF078834);
    final rows =
        <
          ({
            String label,
            String asset,
            String status,
            bool complete,
            VoidCallback action,
          })
        >[
          (
            label: 'Experience',
            asset: 'imgSquareCheck',
            status: experienceComplete ? 'Added' : 'Not added',
            complete: experienceComplete,
            action: onExperience,
          ),
          if (configuredSkills.isNotEmpty)
            (
              label: 'Skills',
              asset: 'imgSkills',
              status: '$skillCount of ${configuredSkills.length} selected',
              complete: skillsComplete,
              action: onSkills,
            ),
          if (schema.serviceSetup.availabilityEnabled)
            (
              label: 'Weekly Availability',
              asset: 'imgSquareCheck',
              status: availabilityComplete ? 'Added' : 'Not added',
              complete: availabilityComplete,
              action: onEdit,
            ),
          if (option.usesServiceAreas(schema.serviceSetup))
            (
              label: 'Location & Area',
              asset: 'imgLocation',
              status: locationComplete
                  ? (onlineOnly ? 'Online' : 'Added')
                  : 'Not added',
              complete: locationComplete,
              action: onEdit,
            ),
          if (additionalFields.isNotEmpty)
            (
              label: 'Additional Information',
              asset: 'imgFileText',
              status: additionalFields.isEmpty
                  ? 'Not required'
                  : additionalComplete && hasAnswer(additionalFields)
                  ? 'Added'
                  : 'Not added',
              complete: additionalComplete,
              action: onEdit,
            ),
        ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RegistrationPanel(
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 49,
                    height: 49,
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: registrationOptionSurface(option),
                      shape: BoxShape.circle,
                    ),
                    child: RegistrationOptionArtwork(option: option),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: InkWell(
                      onTap: onEdit,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          registrationText(option.name, 15, bold: true),
                          if (option.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 3),
                            registrationText(
                              option.description!,
                              11,
                              color: registrationMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: complete
                          ? const Color(0xFFE1F9ED)
                          : const Color(0xFFFFF3CF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: registrationText(
                      complete ? 'Complete' : 'Incomplete',
                      10,
                      bold: true,
                      color: complete ? green : const Color(0xFFD38714),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip:
                          '${expanded ? 'Collapse' : 'Expand'} ${option.name}',
                      onPressed: onToggle,
                      icon: RotatedBox(
                        quarterTurns: expanded ? 0 : 3,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: RegistrationAsset('details_imgDisclosure2'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                for (final (index, row) in rows.indexed)
                  InkWell(
                    key: ValueKey('option-${option.optionId}-${row.label}'),
                    onTap: row.action,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 41),
                      padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: index == rows.length - 1
                                ? Colors.transparent
                                : registrationBorder,
                            width: .6,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: RegistrationAsset(
                              row.complete
                                  ? 'details_imgCircleCheck'
                                  : 'details_${row.asset}',
                            ),
                          ),
                          const SizedBox(width: 17),
                          Expanded(child: registrationText(row.label, 12)),
                          const SizedBox(width: 4),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: registrationText(
                                row.status,
                                11,
                                color: row.complete ? green : registrationMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const RotatedBox(
                            quarterTurns: 3,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: RegistrationAsset(
                                'details_imgDisclosure3',
                              ),
                            ),
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
          top: -8,
          child: SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Remove ${option.name}',
              onPressed: onRemove,
              icon: const SizedBox(
                width: 30,
                height: 30,
                child: RegistrationAsset('details_imgDisclosure4'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
