import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomerStartupSplash extends StatelessWidget {
  const CustomerStartupSplash({super.key});
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.white,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: Colors.white,
      body: Semantics(
        label: 'Starting Bthere',
        liveRegion: true,
        child: LayoutBuilder(
          builder: (context, bounds) => Center(
            child: SvgPicture.asset(
              'assets/branding/bthere_splash_logo.svg',
              key: const ValueKey('customer-startup-logo'),
              width: math.min(240.0, math.max(0.0, bounds.maxWidth - 64)),
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    ),
  );
}
