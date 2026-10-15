import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../home/presentation/provider_home_widgets.dart';

const registrationInk = Color(0xFF09153E);
const registrationMuted = Color(0xFF747FA2);
const registrationTeal = Color(0xFF00858D);
const registrationBorder = Color(0xFFE2E6EF);

Text registrationText(
  String value,
  double size, {
  bool bold = false,
  Color color = registrationInk,
  String fontFamily = 'HomeInter',
  FontWeight? weight,
}) => Text(
  value,
  style: TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    letterSpacing: 0,
    height: 1.35,
    fontWeight: weight ?? (bold ? FontWeight.w700 : FontWeight.w400),
    color: color,
  ),
);

class RegistrationAsset extends StatelessWidget {
  const RegistrationAsset(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/registration/$name.svg',
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class RegistrationOptionSymbol extends StatelessWidget {
  const RegistrationOptionSymbol(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) {
    final label = name.toLowerCase();
    final asset = label.contains('hospital')
        ? 'details_imgPostHospitalCare'
        : label.contains('child')
        ? 'details_imgIllustrationBadge'
        : label.contains('special') || label.contains('disab')
        ? 'details_imgIllustrationBadge1'
        : label.contains('elder') || label.contains('care')
        ? 'details_imgServiceSymbol'
        : null;
    return asset == null
        ? const Icon(Icons.work_outline, color: registrationTeal)
        : RegistrationAsset(asset);
  }
}

/// Intrinsic, scrollable content on the design's 430-point coordinate grid.
/// Device status and navigation bars are provided by the operating system.
class RegistrationPage extends StatelessWidget {
  const RegistrationPage({
    required this.step,
    required this.child,
    required this.onBack,
    this.busy = false,
    super.key,
  });
  final int step;
  final Widget child;
  final VoidCallback onBack;
  final bool busy;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Theme(
      data: BThereTheme.authentication(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !busy) onBack();
        },
        child: DecoratedBox(
          decoration: homeGradient,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height:
                        (90 * MediaQuery.sizeOf(context).width / 430 -
                                MediaQuery.paddingOf(context).top)
                            .clamp(48, 90),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -143,
                          top: -150 - MediaQuery.paddingOf(context).top,
                          width: 355,
                          height: 279,
                          child: const RegistrationAsset(
                            'selection_imgBackgroundGlow',
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 0,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: busy ? null : onBack,
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          child: registrationText(
                            'Register a Service',
                            14,
                            bold: true,
                            color: Colors.white,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        key: ValueKey('registration-scroll-$step'),
                        child: HomeScale(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(26, 20, 26, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: registrationText(
                                    'Step $step of 5',
                                    11,
                                    color: registrationMuted,
                                  ),
                                ),
                                SizedBox(
                                  height: step == 5
                                      ? 4
                                      : step == 1
                                      ? 13
                                      : 9,
                                ),
                                Semantics(
                                  label: 'Registration step $step of 5',
                                  child: Row(
                                    children: [
                                      for (var i = 1; i <= 5; i++) ...[
                                        if (i > 1) const SizedBox(width: 5),
                                        Expanded(
                                          child: Container(
                                            height: 6.5,
                                            decoration: BoxDecoration(
                                              color: i <= step
                                                  ? registrationTeal
                                                  : const Color(0xFFDCE1E8),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: step == 5
                                      ? 25
                                      : step == 3
                                      ? 19
                                      : step == 4
                                      ? 38
                                      : 40,
                                ),
                                child,
                                SizedBox(
                                  height: MediaQuery.paddingOf(context).bottom,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RegistrationButton extends StatelessWidget {
  const RegistrationButton(
    this.label, {
    required this.onPressed,
    this.busy = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 49,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: registrationTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : registrationText(label, 14, bold: true, color: Colors.white),
    ),
  );
}

class RegistrationPanel extends StatelessWidget {
  const RegistrationPanel({
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: const BorderSide(color: registrationBorder, width: .8),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class RegistrationHeading extends StatelessWidget {
  const RegistrationHeading(
    this.title,
    this.description, {
    this.fontFamily = 'HomeInter',
    super.key,
  });
  final String title, description;
  final String fontFamily;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        registrationText(
          title,
          26,
          bold: true,
          fontFamily: fontFamily,
          weight: fontFamily == 'Nunito' ? FontWeight.w900 : FontWeight.w700,
        ),
        const SizedBox(height: 7),
        registrationText(
          description,
          14.5,
          color: registrationMuted,
          fontFamily: fontFamily,
        ),
      ],
    ),
  );
}

class RegistrationSection extends StatelessWidget {
  const RegistrationSection(
    this.title,
    this.description, {
    required this.child,
    this.trailing,
    super.key,
  });
  final String title, description;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (trailing == null)
          registrationText(title, 13, bold: true)
        else
          Row(
            children: [
              Expanded(child: registrationText(title, 13, bold: true)),
              trailing!,
            ],
          ),
        if (description.isNotEmpty)
          registrationText(description, 10.5, color: registrationMuted),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class RegistrationNotice extends StatelessWidget {
  const RegistrationNotice(this.message, {this.warning = false, super.key});
  final String message;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF7EB) : const Color(0xFFEFFBFA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info,
          size: 19,
          color: warning ? Colors.orange : registrationTeal,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: registrationText(message, 10.5, color: registrationMuted),
        ),
      ],
    ),
  );
}
