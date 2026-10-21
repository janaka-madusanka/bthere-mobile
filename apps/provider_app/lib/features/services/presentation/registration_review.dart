import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../application/service_detail_controller.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import 'registration_widgets.dart';
import '../application/registration_payload.dart';

class RegistrationReview extends StatelessWidget {
  const RegistrationReview({
    required this.value,
    required this.draft,
    required this.onEdit,
    required this.onSubmit,
    this.busy = false,
    super.key,
  });
  final ServiceDetailState value;
  final Map<String, dynamic> draft;
  final ValueChanged<int> onEdit;
  final VoidCallback onSubmit;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final answers = registrationAnswers(draft, selected: value.selected);
    final fields = activeRegistrationFields(value.schema, value.selected);
    String answerText(ProviderRequirementField field) {
      final answer = answers['${field.fieldId}'];
      if (answer == null) return '';
      if (answer is bool) return answer ? 'Yes' : 'No';
      if ([
        'IMAGE_UPLOAD',
        'FILE_UPLOAD',
        'DOCUMENT_UPLOAD',
      ].contains(field.fieldType)) {
        final count = registrationFiles(answer)?.length ?? 0;
        return count == 0 ? '' : '$count uploaded file${count == 1 ? '' : 's'}';
      }
      String label(Object? value) {
        for (final choice
            in field.options is List ? field.options as List : const []) {
          if (choice is Map &&
              choice['value'] == value &&
              choice['label'] is String) {
            return choice['label'] as String;
          }
        }
        return value?.toString() ?? '';
      }

      return answer is List ? answer.map(label).join(', ') : label(answer);
    }

    final areas = value.schema.options
        .where((o) => value.selected.contains(o.optionId))
        .expand(
          (option) => option
              .locationGroups(
                (draft['options'] as Map? ?? {})['${option.optionId}']
                        as Map? ??
                    {},
              )
              .values,
        )
        .expand((group) => group['areas'] as List? ?? [])
        .whereType<Map>()
        .map((a) => a['locationName'] ?? a['city'])
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .join(', ');
    final languageValues = (draft['languages'] as List? ?? [])
        .where((v) => v.toString().isNotEmpty)
        .map((v) => v.toString()[0] + v.toString().substring(1).toLowerCase())
        .toList();
    final skillIds = registrationSkillIds(value.schema, draft);
    final skillValues = value.schema.serviceSetup.skills
        .where((skill) => skillIds.contains(skill.metadata['skillId']))
        .map((skill) => skill.metadata['name'])
        .whereType<String>()
        .toList();
    final certificates =
        ((draft['server'] as Map? ?? {})['certificates'] as List? ?? [])
            .whereType<Map>()
            .map((record) => record['name'])
            .whereType<String>()
            .toList();
    final documents = (draft['documentNames'] as List? ?? [])
        .whereType<String>()
        .toList();
    Widget chips(List<String> labels) => Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final (i, label) in labels.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: i.isEven
                  ? const Color(0xFFE7FAF7)
                  : const Color(0xFFF0F1F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: registrationText(label, 9.7, color: registrationMuted),
          ),
      ],
    );
    Widget row(
      String title,
      String description,
      String asset,
      Color background, {
      int step = 2,
      Widget? content,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RegistrationPanel(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 46,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: RegistrationAsset('review_$asset'),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  registrationText(title, 12, bold: true),
                  const SizedBox(height: 3),
                  (description.isNotEmpty ? content : null) ??
                      registrationText(
                        description.isEmpty ? 'Not added' : description,
                        11.2,
                        color: registrationMuted,
                      ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(50, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => onEdit(step),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: RegistrationAsset('review_imgEditIcon'),
                  ),
                  const SizedBox(width: 5),
                  registrationText('Edit', 10, color: registrationTeal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RegistrationHeading(
          'Review Your Service',
          'Please review your details before submitting.',
        ),
        row(
          'Service',
          value.service.name,
          'imgHandHeart',
          const Color(0xFFE7FAF7),
        ),
        row(
          'Years of Experience',
          '${value.experience} years',
          'imgExperience',
          const Color(0xFFE7F3FF),
        ),
        for (final field in fields)
          if (registrationFieldVisible(field, answers, fields) == true)
            row(
              field.label,
              answerText(field),
              'imgDescription',
              const Color(0xFFE7FAF7),
            ),
        if (value.schema.options.any(
          (o) =>
              value.selected.contains(o.optionId) &&
              o.usesServiceAreas(value.schema.serviceSetup),
        ))
          row(
            'Service Locations',
            areas.isEmpty &&
                    value.schema.options
                        .where((o) => value.selected.contains(o.optionId))
                        .every((o) => o.configuredLocationMode() == 'ONLINE')
                ? 'Online'
                : areas,
            'imgLocation',
            const Color(0xFFF0EAFF),
          ),
        if (value.schema.serviceSetup.skills.isNotEmpty)
          row(
            'Skills',
            skillValues.join(', '),
            'imgSkills',
            const Color(0xFFE7FAF7),
            content: chips(skillValues),
          ),
        if (value.schema.serviceSetup.certificates.level !=
            ProviderRequirementLevel.disabled)
          row(
            'Certifications',
            certificates.join(', '),
            'imgCertificate',
            const Color(0xFFE7F3FF),
            step: 3,
            content: chips(certificates),
          ),
        if (value.schema.serviceSetup.documents.isNotEmpty ||
            documents.isNotEmpty)
          row(
            'Additional Documents',
            documents.join(', '),
            'imgAdditionalDocument',
            const Color(0xFFFFF1EA),
            step: 3,
            content: chips(documents),
          ),
        if (value.schema.serviceSetup.education.level !=
            ProviderRequirementLevel.disabled)
          row(
            'Education',
            ((draft['server'] as Map? ?? {})['education'] as List? ?? [])
                .whereType<Map>()
                .map(
                  (e) =>
                      e['title'] ??
                      e['qualification'] ??
                      e['instituteName'] ??
                      '',
                )
                .join(', '),
            'imgCertificate',
            const Color(0xFFE7F3FF),
            step: 3,
          ),
        row(
          'Languages',
          languageValues.join(', '),
          'imgLanguages',
          const Color(0xFFE7FAF7),
          content: chips(languageValues),
        ),
        const SizedBox(height: 16),
        RegistrationButton(
          'Submit for Review',
          onPressed: onSubmit,
          busy: busy,
        ),
      ],
    );
  }
}

/// Display after all required data is persisted and completion is refreshed.
class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({
    this.approved = false,
    this.firstStep = 1,
    super.key,
  });
  final bool approved;
  final int firstStep;
  @override
  Widget build(BuildContext context) => RegistrationPage(
    step: 5,
    firstStep: firstStep,
    onBack: () => context.go(AppRoutes.home),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 237,
            height: 127,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  left: 70,
                  top: 29,
                  width: 97,
                  height: 97,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFCCF7F1), Color(0xFFDBFBF7)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 65,
                        height: 65,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF00A9A8),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 49,
                              height: 49,
                              child: RegistrationAsset(
                                'complete_imgCompletedCheck',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 1.38,
                  top: 6.93,
                  width: 237,
                  height: 127,
                  child: RegistrationAsset('complete_imgCelebrationLeaves'),
                ),
                for (final (i, x, y, w, h) in [
                  (0, 57.0, 56.0, 3.5, 3.5),
                  (1, 56.0, 23.0, 4.0, 4.0),
                  (2, 49.0, 34.0, 8.5, 8.5),
                  (3, 204.0, 44.0, 7.5, 7.5),
                  (4, 185.0, 59.0, 7.5, 8.0),
                  (5, 160.0, 18.0, 6.0, 5.0),
                  (6, 106.0, 3.0, 8.0, 8.0),
                  (7, 70.0, 4.0, 10.0, 10.0),
                ])
                  Positioned(
                    left: x,
                    top: y,
                    width: w,
                    height: h,
                    child: RegistrationAsset(
                      'complete_imgConfettiDot${i == 0 ? '' : i}',
                    ),
                  ),
                Positioned(
                  left: 139,
                  top: 3,
                  child: Transform.rotate(
                    angle: .3,
                    child: Container(
                      width: 4,
                      height: 17,
                      decoration: BoxDecoration(
                        color: const Color(0xFF09B7AD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 21),
        const Center(
          child: Text(
            'All Set!',
            style: TextStyle(
              fontFamily: 'HomeInter',
              fontSize: 32,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: registrationInk,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: registrationText(
            'Your service registration is complete.',
            16,
            color: registrationMuted,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Thank you for joining Bthere as a service provider.\nWe’ve received your information and documents.\nOur team will review them shortly.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'HomeLato',
            fontSize: 12.8,
            height: 1.4,
            color: registrationMuted,
          ),
        ),
        const SizedBox(height: 18),
        RegistrationPanel(
          color: const Color(0xFFEFFBFA),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFD8F9F5),
                  shape: BoxShape.circle,
                ),
                child: const RegistrationAsset('complete_imgClock'),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    registrationText(
                      approved ? 'Approved' : 'Under Review',
                      14,
                      bold: true,
                    ),
                    const SizedBox(height: 4),
                    registrationText(
                      approved
                          ? 'Your service is approved and ready to receive booking requests.'
                          : 'We’ll verify your details and documents.\nYou’ll be notified once your service is approved.',
                      10.5,
                      color: registrationMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(color: registrationBorder),
        ),
        registrationText('What happens next?', 17, bold: true),
        const SizedBox(height: 5),
        registrationText(
          'Here’s what you can expect after registration.',
          12,
          color: registrationMuted,
        ),
        const SizedBox(height: 16),
        for (final (asset, title, description) in [
          (
            'imgReviewDocuments',
            '1. Review Process',
            'Our team will review your profile, documents, and service details.',
          ),
          (
            'imgApprovalNotification',
            '2. Get Notified',
            'You’ll receive a notification once your service is approved.',
          ),
          (
            'imgApprovedCheck',
            '3. Start Receiving Opportunities',
            'After approval, your service will be visible and you can start receiving booking requests.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: EdgeInsets.all(
                    asset == 'imgApprovedCheck' ? 12.5 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: asset == 'imgApprovedCheck'
                        ? const Color(0xFF00B28C)
                        : asset == 'imgReviewDocuments'
                        ? const Color(0xFFE7F7FF)
                        : asset == 'imgApprovalNotification'
                        ? const Color(0xFFFFF6E8)
                        : const Color(0xFFE2FAF3),
                    shape: BoxShape.circle,
                  ),
                  child: RegistrationAsset('complete_$asset'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          registrationText(title, 12, bold: true),
                          if (asset == 'imgReviewDocuments')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F7FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: registrationText(
                                '1–2 business days',
                                9,
                                color: const Color(0xFF009CF3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      registrationText(
                        description,
                        11,
                        color: registrationMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        RegistrationButton(
          'Go to Home',
          onPressed: () => context.go(AppRoutes.home),
        ),
      ],
    ),
  );
}
