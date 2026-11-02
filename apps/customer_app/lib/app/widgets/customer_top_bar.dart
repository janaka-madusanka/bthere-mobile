import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class CustomerTopBar extends StatelessWidget {
  const CustomerTopBar({super.key, this.photo});
  final String? photo;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(child: CustomerHeaderBackground()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 4, 18, 10),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/branding/home_logo.svg',
                    width: 84,
                    height: 31,
                    semanticsLabel: 'B there',
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('customer-home-notifications'),
                    tooltip: 'Notifications',
                    onPressed: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Notifications coming soon.'),
                        ),
                      ),
                    icon: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    key: const ValueKey('customer-home-account'),
                    tooltip: 'Your profile',
                    onPressed: () => context.go('/account'),
                    icon: _ProfileAvatar(url: photo),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CustomerHeaderBackground extends StatelessWidget {
  const CustomerHeaderBackground({super.key});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Transform.scale(
      // Exclude the exported bitmap's baked checkerboard frame.
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
  const _ProfileAvatar({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: 34,
      height: 34,
      child: ColoredBox(
        color: Colors.white.withValues(alpha: .08),
        child: url == null
            ? const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 23,
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
      ),
    ),
  );
}
