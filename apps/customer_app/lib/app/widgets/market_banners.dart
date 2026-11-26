import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../customer_providers.dart';

final _repository = Provider(
  (ref) => MarketBannerRepository(ref.watch(customerApiClientProvider)),
  dependencies: [customerApiClientProvider],
);

class CustomerMarketBanners extends ConsumerWidget {
  const CustomerMarketBanners({super.key, required this.marketId});
  final int marketId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(_repository);
    return BthereBannerCarousel(
      key: ValueKey('banners-customer-$marketId'),
      aspectRatio: 1.8,
      load: () async {
        final banners = await repository.load(marketId, 'CUSTOMER');
        return [
          for (final banner in banners)
            BannerSlide(
              id: banner.id,
              title: banner.title,
              imageUrl: banner.imageUrl,
              onTap: banner.linkType == 'NONE'
                  ? null
                  : () async {
                      if (!context.mounted) return;
                      switch (banner.linkType) {
                        case 'SERVICE':
                          context.push('/services?service=${banner.serviceId}');
                        case 'OPTION':
                          context.push(
                            '/booking/${banner.serviceId}/${banner.optionId}',
                          );
                        case 'URL':
                          try {
                            if (!await launchUrl(
                              banner.linkUrl!,
                              mode: LaunchMode.externalApplication,
                            )) {
                              throw StateError('Link unavailable');
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to open this link. Please try again.',
                                  ),
                                ),
                              );
                            }
                          }
                      }
                    },
            ),
        ];
      },
    );
  }
}
