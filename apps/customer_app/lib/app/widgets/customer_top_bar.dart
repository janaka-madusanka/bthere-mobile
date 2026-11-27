import '../../features/discovery/domain/customer_discovery.dart'
    show safeImageUrl;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/application/customer_profile_controller.dart';

import 'package:go_router/go_router.dart';

import 'customer_content_surface.dart';

import '../../features/booking/presentation/customer_notification_host.dart';

class CustomerTopBar extends ConsumerWidget {
  const CustomerTopBar({super.key, this.extendBehindContent = false});
  final bool extendBehindContent;
  static const toolbarHeight = 68.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileControllerProvider);
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) => _build(
        context,
        profile.profile?.details.firstName,
        safeImageUrl(profile.profile?.details.profilePhoto),
      ),
    );
  }

  Widget _build(BuildContext context, String? name, String? photo) =>
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Continue the same artwork behind the rounded content corners.
            // This affects paint only; toolbar/content layout stays unchanged.
            Positioned.fill(
              bottom: extendBehindContent
                  ? -CustomerContentSurface.cornerRadius
                  : 0,
              child: const ColoredBox(color: Colors.white),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/branding/bthere_splash_logo.svg',
                      width: 112,
                      height: 42,
                      semanticsLabel: 'B there',
                    ),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('customer-home-notifications'),
                      tooltip: 'Notifications',
                      onPressed: () =>
                          showCustomerNotificationSettings(context),
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF164B55),
                          size: 21,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      key: const ValueKey('customer-home-account'),
                      tooltip: 'Your profile',
                      onPressed: () => context.go('/account'),
                      icon: _ProfileAvatar(url: photo, name: name),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class CustomerHeaderBackground extends StatelessWidget {
  const CustomerHeaderBackground({super.key});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Transform.scale(
      // Keep the original wallet artwork's exported frame outside the bounds.
      scale: 1.2,
      child: Image.asset(
        'assets/branding/home_header_background.png',
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.url, this.name});
  final String? name;
  final String? url;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: 36,
      height: 36,
      child: ColoredBox(
        color: const Color(0xFFE1F4F1),
        child: url == null
            ? _initial()
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initial(),
              ),
      ),
    ),
  );
  Widget _initial() {
    final text = name?.trim() ?? '';
    return Center(
      child: text.isEmpty
          ? const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF0D4050),
              size: 21,
            )
          : Text(
              text.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF0D4050),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
