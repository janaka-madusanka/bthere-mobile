import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import 'brand_image.dart';

/// Shared bright presentation only; it owns no authentication or routing state.
class BrandedFormPage extends StatelessWidget {
  const BrandedFormPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerAction,
    this.onRefresh,
    this.compactHeader = false,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? headerAction;
  final Future<void> Function()? onRefresh;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) => Theme(
    data: BThereTheme.authentication(),
    child: Builder(
      builder: (context) => Scaffold(
        body: BThereBrandedBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final scroll = SingleChildScrollView(
                  physics: onRefresh == null
                      ? null
                      : const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                    horizontal: bounds.maxWidth < 360
                        ? BThereSpacing.md
                        : bounds.maxWidth >= 400
                        ? BThereSpacing.xxl
                        : BThereSpacing.lg,
                    vertical: BThereSpacing.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: BThereBrandImage(
                              asset: BThereBrandAsset.carePromise,
                              width: compactHeader ? 88 : 124,
                              semanticLabel: 'B there Provider — Care Promise',
                            ),
                          ),
                          const SizedBox(height: BThereSpacing.xs),
                          Text(
                            'B there Provider',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          SizedBox(
                            height: compactHeader
                                ? BThereSpacing.md
                                : BThereSpacing.lg,
                          ),
                          if (headerAction != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge,
                                    ),
                                  ),
                                ),
                                headerAction!,
                              ],
                            )
                          else
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge,
                              ),
                            ),
                          if (subtitle case final description?
                              when description.trim().isNotEmpty) ...[
                            const SizedBox(height: BThereSpacing.xs),
                            Text(
                              description,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                          const SizedBox(height: BThereSpacing.lg),
                          child,
                        ],
                      ),
                    ),
                  ),
                );
                return onRefresh == null
                    ? scroll
                    : RefreshIndicator(onRefresh: onRefresh!, child: scroll);
              },
            ),
          ),
        ),
      ),
    ),
  );
}
