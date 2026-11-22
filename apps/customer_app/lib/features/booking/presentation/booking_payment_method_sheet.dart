import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';

class BookingPaymentMethodSheet extends StatelessWidget {
  const BookingPaymentMethodSheet({
    super.key,
    required this.currentMethod,
    required this.onSelected,
  });

  final String currentMethod;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Choose payment method',
                  style: CustomerTypography.section,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: currentMethod,
            onChanged: (method) {
              if (method != null && method != currentMethod) onSelected(method);
            },
            child: Column(
              children: [
                for (final method in ['CARD', 'WALLET'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _method(method),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _method(String method) {
    final current = currentMethod == method;
    final wallet = method == 'WALLET';
    return Material(
      color: current ? CustomerColors.selection : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: RadioListTile<String>(
        key: ValueKey('retry-payment-method-$method'),
        value: method,
        enabled: !current,
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6),
        activeColor: CustomerColors.action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: current ? CustomerColors.action : CustomerColors.border,
          ),
        ),
        title: Text(
          wallet ? 'BThere Wallet' : 'Credit / Debit Card',
          style: CustomerTypography.compactStrong.copyWith(
            color: CustomerColors.text,
          ),
        ),
        subtitle: Text(
          current
              ? 'Current payment method'
              : wallet
              ? 'Use your available wallet balance'
              : 'Select a card to retry payment',
          style: CustomerTypography.micro.copyWith(
            color: CustomerColors.secondaryText,
          ),
        ),
        secondary: wallet
            ? SvgPicture.asset(
                'assets/icons/navigation/wallet_selected.svg',
                width: 22,
                height: 22,
                semanticsLabel: 'BThere Wallet',
                colorFilter: const ColorFilter.mode(
                  CustomerColors.action,
                  BlendMode.srcIn,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/payment/mastercard.svg',
                    width: 20,
                    height: 16,
                    semanticsLabel: 'Mastercard',
                  ),
                  const SizedBox(width: 6),
                  SvgPicture.asset(
                    'assets/icons/payment/visa.svg',
                    width: 24,
                    height: 16,
                    semanticsLabel: 'Visa',
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF1434CB),
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
