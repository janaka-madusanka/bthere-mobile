import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../presentation/onboarding_screen.dart';
import '../application/provider_requirements_controller.dart';
import '../domain/provider_requirement_section.dart';

class ProviderRequirementsScreen extends ConsumerWidget {
  const ProviderRequirementsScreen({
    super.key,
    this.section,
    this.assignmentId,
    this.serviceTypeId,
  });
  final ProviderRequirementSection? section;
  final int? assignmentId, serviceTypeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerRequirementsControllerProvider);
    final result = state.asData?.value;
    final controller = ref.read(
      providerRequirementsControllerProvider.notifier,
    );
    Widget content;
    if (state.isLoading) {
      content = const BThereLoadingState(label: 'Loading service requirements');
    } else if (result is Success<ProviderRequirementsOverview>) {
      final v = result.value, rows = v.rows;
      if (section != null) {
        final target = v.assignments
            .where(
              (s) =>
                  s.assignmentId == assignmentId &&
                  s.serviceTypeId == serviceTypeId,
            )
            .firstOrNull;
        if (target != null && target.assignmentId != v.selected.assignmentId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ref.context.mounted) controller.select(target.assignmentId);
          });
          return const OnboardingPage(
            child: BThereLoadingState(label: 'Loading selected service'),
          );
        }
        final valid =
            assignmentId == v.selected.assignmentId &&
            serviceTypeId == v.selected.serviceTypeId &&
            rows.any((r) => r.section == section);
        content = Column(
          children: [
            Text(
              valid ? section!.label : 'Section unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              valid
                  ? '${v.selected.serviceName} setup will be available here soon.'
                  : 'Choose an applicable section from your service overview.',
            ),
            BThereButton(
              label: 'Back to requirements',
              onPressed: () => context.go(AppRoutes.serviceRequirements),
            ),
          ],
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Complete your service requirements',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (v.assignments.length > 1)
              DropdownButtonFormField<int>(
                initialValue: v.selected.assignmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Service'),
                items: v.assignments
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.assignmentId,
                        child: Text(
                          s.serviceName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) controller.select(id);
                },
              ),
            Text(
              v.selected.serviceName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${rows.where((r) => r.completed).length} of ${rows.length} sections completed',
            ),
            Text(
              'Overall account setup: ${v.completion.completionPercentage}%',
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Text(
                'No applicable requirement sections are configured for this service.',
              ),
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text(row.section.label),
                  subtitle: Text(
                    '${row.completed ? 'Completed' : 'Needs attention'}${row.level == null ? '' : ' · ${row.level!.name}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    '${AppRoutes.serviceRequirements}/${row.section.slug}?assignmentId=${v.selected.assignmentId}&serviceTypeId=${v.selected.serviceTypeId}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            BThereButton(
              label: 'Refresh requirements',
              onPressed: controller.refresh,
            ),
          ],
        );
      }
    } else {
      content = BThereStateView(
        title: 'Unable to load requirements',
        message: result is Failure<ProviderRequirementsOverview>
            ? result.failure.message
            : 'Please try again.',
        action: BThereButton(label: 'Retry', onPressed: controller.refresh),
      );
    }
    return OnboardingPage(child: content);
  }
}
