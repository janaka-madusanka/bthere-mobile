import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/brand_image.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';

import 'package:bthere_common/bthere_common.dart';

import '../../onboarding/application/provider_entry_gate.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appSessionStateProvider);
    final session = state.asData?.value;
    final gate = ref.watch(providerEntryGateProvider);
    final gateResult = gate.asData?.value;
    final gateFailed =
        session == AppSessionState.authenticated &&
        (gate.hasError || (!gate.isLoading && gateResult is Failure<bool>));
    final message = gateFailed
        ? (gateResult is Failure<bool>
              ? gateResult.failure.message
              : entryCheckFailure.message)
        : switch (session) {
            AppSessionState.configurationFailure => 'Configuration required: supply a valid BTHERE_API_BASE_URL with --dart-define.',
            AppSessionState.restorationFailure => 'Unable to restore the secure session. Please restart the app to try again.',
            _ =>
              state.hasError
                  ? 'Unable to start the app. Please restart to try again.'
                  : null,
          };
    return StartupLoadingPage(
      message: message,
      onRetry: gateFailed
          ? () => ref.read(providerEntryGateProvider.notifier).retry()
          : null,
    );
  }
}

/// Startup remains light even when the device uses dark mode.
class StartupLoadingPage extends StatelessWidget {
  const StartupLoadingPage({super.key, this.message, this.onRetry});
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.light,
      fontFamily: 'PublicSans',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff008b92)),
    ),
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xfff7fdfc),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xfff7fdfc),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BThereSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandPulse(),
                  const SizedBox(height: 40),
                  const Text(
                    'A little care. A world of difference.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff093d55),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message ?? 'Getting things ready for you…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xff607a83),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (onRetry != null)
                    BThereButton(
                      label: 'Retry account setup',
                      onPressed: onRetry,
                    ),
                  if (message == null)
                    Semantics(
                      label: 'Starting Bthere Provider',
                      liveRegion: true,
                      child: SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: MediaQuery.disableAnimationsOf(context)
                                ? 0.5
                                : null,
                            color: const Color(0xff008b92),
                            backgroundColor: const Color(0xffdaefed),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 36),
                  const Text(
                    'BTHERE  •  PROVIDER',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff008b92),
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

class _BrandPulse extends StatefulWidget {
  const _BrandPulse();
  @override
  State<_BrandPulse> createState() => _BrandPulseState();
}

class _BrandPulseState extends State<_BrandPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      controller.value = 0;
    } else {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    height: 280,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 0.94 + controller.value * 0.06,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffe8f7f4),
              ),
            ),
          ),
          Container(
            width: 236,
            height: 236,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xffccebe6)),
            ),
          ),
          Container(
            width: 208,
            height: 208,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(52),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12008b92),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: child,
          ),
          const Positioned(
            right: 8,
            top: 44,
            child: Icon(Icons.auto_awesome, size: 24, color: Color(0xff00a6a7)),
          ),
          const Positioned(
            left: 18,
            bottom: 38,
            child: Icon(
              Icons.favorite_rounded,
              size: 20,
              color: Color(0xff62cfc2),
            ),
          ),
        ],
      ),
      child: const BThereBrandImage(
        asset: BThereBrandAsset.carePromise,
        width: 178,
        semanticLabel: 'Bthere. Care when it matters.',
      ),
    ),
  );
}
