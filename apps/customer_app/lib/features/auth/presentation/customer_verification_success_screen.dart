import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../application/customer_auth_controller.dart';
import 'customer_brand_image.dart';

class CustomerVerificationSuccessScreen extends ConsumerWidget {
  const CustomerVerificationSuccessScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider);
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => CustomerVerificationSuccessPage(
        phone: auth.verificationSuccess == CustomerVerificationChannel.phone,
        onContinue: auth.continueAfterVerification,
      ),
    );
  }
}

class CustomerVerificationSuccessPage extends StatelessWidget {
  const CustomerVerificationSuccessPage({
    super.key,
    required this.phone,
    required this.onContinue,
  });
  final bool phone;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final theme = CustomerTheme.authentication();
    const navy = Color(0xFF0B3037), muted = Color(0xFF8398B8);
    Widget item(String title, String detail) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDEF8F4),
              border: Border.all(color: const Color(0xFFF6FDFD), width: 5),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF00AAA9),
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Theme(
      data: theme,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onContinue();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFB),
          body: BThereBrandedBackground(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  key: const ValueKey('customer-verification-success-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    ((bounds.maxHeight - 700) * .3).clamp(24.0, 72.0),
                    24,
                    36,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: BThereBrandImage(
                              asset: BThereBrandAsset.carePromise,
                              width: 180,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Center(child: VerificationSuccessAnimation()),
                          const SizedBox(height: 16),
                          Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(
                              phone ? 'Phone verified!' : 'Email verified!',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: navy,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            phone
                                ? 'Your phone number has been successfully verified.'
                                : 'Your email has been successfully verified.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: muted,
                              fontSize: 18,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF9FA),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                item(
                                  'Account ready',
                                  'Your Bthere Customer account is ready.',
                                ),
                                item(
                                  phone ? 'Phone verified' : 'Email verified',
                                  'You can now continue securely.',
                                ),
                                item(
                                  'Next step',
                                  'Continue to your profile or Customer account.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          BTherePrimaryButton(
                            key: const ValueKey(
                              'customer-verification-success-continue',
                            ),
                            label: 'Continue',
                            onPressed: onContinue,
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

class VerificationSuccessAnimation extends StatefulWidget {
  const VerificationSuccessAnimation({super.key});
  @override
  State<VerificationSuccessAnimation> createState() =>
      _VerificationSuccessAnimationState();
}

class _VerificationSuccessAnimationState
    extends State<VerificationSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  bool _reduceMotion = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _animation.stop();
      _animation.value = 1;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Verification successful',
    image: true,
    child: ExcludeSemantics(
      child: Lottie.asset(
        'assets/animations/verification_success.json',
        key: const ValueKey('customer-verification-success-animation'),
        controller: _animation,
        width: 170,
        height: 170,
        fit: BoxFit.contain,
        repeat: false,
        onLoaded: (composition) {
          _animation.duration = composition.duration;
          if (_reduceMotion) {
            _animation.value = 1;
          } else {
            _animation.forward(from: 0);
          }
        },
        errorBuilder: (_, _, _) => const SizedBox(
          width: 170,
          height: 170,
          child: Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF27C4AD),
            size: 124,
          ),
        ),
      ),
    ),
  );
}
