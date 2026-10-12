import 'package:flutter/material.dart';

import '../theme/bthere_colors.dart';
import 'bthere_loading_indicator.dart';

/// Accessible loading presentation for pages, sections and inline fields.
/// Callers retain ownership of requests, errors and retry behavior.
class BThereLoadingState extends StatelessWidget {
  const BThereLoadingState({
    super.key,
    required this.label,
    this.message,
    this.placeholder,
    this.compact = false,
  });

  final String label;
  final String? message;
  final Widget? placeholder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final indicator = ExcludeSemantics(
      child: BThereLoadingIndicator(
        size: compact ? 20 : 32,
        color: BThereColors.primaryAction,
      ),
    );
    final title = Text(
      label,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: message == null ? label : '$label. $message',
      excludeSemantics: true,
      child: compact
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  indicator,
                  const SizedBox(width: 12),
                  Expanded(child: title),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BThereColors.primaryAction.withValues(
                          alpha: .07,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: indicator,
                    ),
                  ),
                  const SizedBox(height: 16),
                  title,
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (placeholder != null) ...[
                    const SizedBox(height: 24),
                    IgnorePointer(child: placeholder!),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Neutral placeholder block; no fabricated content or interactive semantics.
class BThereSkeleton extends StatelessWidget {
  const BThereSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });
  final double? width;
  final double height, radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF1F2),
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
