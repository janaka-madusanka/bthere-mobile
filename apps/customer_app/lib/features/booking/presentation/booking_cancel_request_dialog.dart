import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';

class BookingCancelRequestDialog extends StatelessWidget {
  const BookingCancelRequestDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: CustomerColors.selection,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const ExcludeSemantics(
                    child: Icon(
                      Icons.event_busy_outlined,
                      color: CustomerColors.action,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cancel this request?',
                  textAlign: TextAlign.center,
                  style: CustomerTypography.screen.copyWith(
                    color: CustomerColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This will cancel your current provider request.',
              textAlign: TextAlign.center,
              style: CustomerTypography.body.copyWith(
                color: CustomerColors.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2FAFA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: CustomerColors.action,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your booking details stay with you',
                          style: CustomerTypography.compactStrong.copyWith(
                            color: CustomerColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'You can send a new request without filling them in again.',
                          style: CustomerTypography.compact.copyWith(
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, bounds) {
                final keep = FilledButton(
                  key: const ValueKey('booking-keep-request'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    backgroundColor: CustomerColors.action,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: CustomerTypography.card,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep request'),
                );
                final cancel = TextButton(
                  key: const ValueKey('booking-confirm-cancel-request'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    foregroundColor: const Color(0xFFD64D60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: CustomerTypography.card,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Cancel request'),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [keep, const SizedBox(height: 4), cancel],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
