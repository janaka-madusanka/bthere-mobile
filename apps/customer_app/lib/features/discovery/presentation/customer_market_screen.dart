import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/customer_brand_image.dart';
import '../application/customer_discovery_controller.dart';

const discoveryNavy = Color(0xFF0B3037), discoveryMuted = Color(0xFF687B83);

class CustomerMarketScreen extends ConsumerWidget {
  const CustomerMarketScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(customerDiscoveryProvider);
    return Theme(
      data: CustomerTheme.authentication(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        body: BThereBrandedBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 480,
                        minHeight: (bounds.maxHeight - 48).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Center(
                                    child: BThereBrandImage(
                                      asset: BThereBrandAsset.carePromise,
                                      width: 160,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: IconButton(
                                      tooltip: 'Your account',
                                      onPressed: () => context.go('/account'),
                                      icon: const Icon(Icons.person_outline),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 54,
                                    child: Divider(
                                      color: CustomerColors.action,
                                      thickness: 5,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  SizedBox(
                                    width: 54,
                                    child: Divider(
                                      color: CustomerColors.action,
                                      thickness: 5,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'STEP 2 OF 2',
                                textAlign: TextAlign.center,
                                style: CustomerTypography.compactStrong
                                    .copyWith(color: discoveryMuted),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Where do you need care?',
                                textAlign: TextAlign.center,
                                style: CustomerTypography.screen.copyWith(
                                  color: discoveryNavy,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Choose your market to discover services available in your area.',
                                textAlign: TextAlign.center,
                                style: CustomerTypography.body.copyWith(
                                  color: discoveryMuted,
                                ),
                              ),
                              const SizedBox(height: 32),
                              if (controller.marketStage ==
                                      DiscoveryStage.loading ||
                                  controller.marketStage == DiscoveryStage.idle)
                                const BThereLoadingState(
                                  label: 'Loading available markets',
                                )
                              else if (controller.marketStage ==
                                  DiscoveryStage.failure)
                                BThereStateView(
                                  title: 'Unable to load markets',
                                  message: controller.marketError,
                                  action: BThereButton(
                                    label: 'Retry markets',
                                    onPressed: controller.loadMarkets,
                                  ),
                                )
                              else if (controller.markets.isEmpty)
                                BThereStateView(
                                  title: 'No markets available',
                                  message: 'Please try again later.',
                                  action: BThereButton(
                                    label: 'Refresh markets',
                                    onPressed: controller.loadMarkets,
                                  ),
                                )
                              else ...[
                                Text(
                                  'Available markets',
                                  style: CustomerTypography.section.copyWith(
                                    color: discoveryNavy,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  controller.markets.length == 1
                                      ? 'Your available market is selected.'
                                      : 'Select a market to continue',
                                  style: const TextStyle(color: discoveryMuted),
                                ),
                                const SizedBox(height: 16),
                                if (controller.markets.length > 1) ...[
                                  DropdownButtonFormField<int>(
                                    key: ValueKey(
                                      'customer-market-selector-${controller.candidate?.id}',
                                    ),
                                    initialValue: controller.candidate?.id,
                                    decoration: const InputDecoration(
                                      labelText: 'Market',
                                      prefixIcon: Icon(Icons.public),
                                    ),
                                    isExpanded: true,
                                    items: controller.markets
                                        .map(
                                          (market) => DropdownMenuItem(
                                            value: market.id,
                                            child: Text(market.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: controller.savingMarket
                                        ? null
                                        : (id) {
                                            if (id != null) {
                                              controller.select(id);
                                            }
                                          },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (controller.candidate case final market?)
                                  Container(
                                    key: const ValueKey(
                                      'customer-market-selected',
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3FBFB),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: CustomerColors.action,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            const CircleAvatar(
                                              backgroundColor: Color(
                                                0xFFDDF4F4,
                                              ),
                                              child: Icon(
                                                Icons.public,
                                                color: CustomerColors.action,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    market.name,
                                                    style: CustomerTypography
                                                        .screen
                                                        .copyWith(
                                                          color: discoveryNavy,
                                                        ),
                                                  ),
                                                  Text(
                                                    '${market.countryCode} · ${market.currencyCode} · ${market.timezone}',
                                                    style: CustomerTypography
                                                        .body
                                                        .copyWith(
                                                          color: discoveryMuted,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.check_circle,
                                              color: CustomerColors.action,
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        Text(
                                          'Services and schedules are shown for this market',
                                          style: CustomerTypography.compact
                                              .copyWith(color: discoveryMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (controller.countrySuggested)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Suggested from your saved profile country. You can change it.',
                                      style: CustomerTypography.compact
                                          .copyWith(color: discoveryMuted),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF9FA),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: CustomerColors.action,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Market-based services',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: discoveryNavy,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Pricing currency and times follow your market.',
                                              style: TextStyle(
                                                color: discoveryMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (controller.marketStage ==
                                        DiscoveryStage.ready &&
                                    controller.marketError != null)
                                  BThereInlineError(controller.marketError!),
                                BThereButton(
                                  key: const ValueKey(
                                    'customer-market-continue',
                                  ),
                                  label: 'Continue →',
                                  loading: controller.savingMarket,
                                  onPressed:
                                      controller.marketStage ==
                                              DiscoveryStage.ready &&
                                          controller.candidate != null &&
                                          !controller.savingMarket
                                      ? () async {
                                          final saved = await controller
                                              .continueMarket();
                                          if (saved && context.mounted) {
                                            context.go('/home');
                                          }
                                        }
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'You can change your market later.',
                                  textAlign: TextAlign.center,
                                  style: CustomerTypography.body.copyWith(
                                    color: discoveryMuted,
                                  ),
                                ),
                                if (controller.confirmed)
                                  TextButton(
                                    onPressed: controller.savingMarket
                                        ? null
                                        : () => context.go('/home'),
                                    child: const Text('Back to home'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
