import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';
import '../../wallet/data/customer_wallet_repository.dart';

class BookingSavedCardsDialog extends StatefulWidget {
  const BookingSavedCardsDialog({
    super.key,
    required this.repository,
    required this.onAddCard,
  });
  final CustomerWalletRepository repository;
  final Future<void> Function() onAddCard;
  @override
  State<BookingSavedCardsDialog> createState() =>
      _BookingSavedCardsDialogState();
}

class _BookingSavedCardsDialogState extends State<BookingSavedCardsDialog> {
  List<Map<String, dynamic>> _cards = [];
  int? _selected;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      _cards = snapshot.methods
          .where((m) => m['type'] == 'CARD' && m['status'] == 'VERIFIED_MOCK')
          .toList();
      if (!_cards.any((m) => m['methodId'] == _selected)) {
        _selected = _cards.length == 1
            ? _cards.single['methodId'] as int
            : null;
      }
    } catch (_) {
      if (mounted) {
        _error = 'Saved cards could not be loaded. Please try again.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _ink = Color(0xFF152348);
  static const _muted = Color(0xFF7A849C);

  String _cardTitle(Map<String, dynamic> card) {
    final last4 = card['last4'];
    final label = card['displayLabel'] as String;
    final digits = last4 is String && RegExp(r'^\d{4}$').hasMatch(last4)
        ? last4
        : RegExp(r'(\d{4})\s*$').firstMatch(label)?.group(1);
    return digits == null ? label : '\u2022\u2022\u2022\u2022 $digits';
  }

  String _cardSubtitle(Map<String, dynamic> card) {
    final month = card['expiryMonth'];
    final year = card['expiryYear'];
    if (month is int &&
        month >= 1 &&
        month <= 12 &&
        year is int &&
        year >= 2000 &&
        year <= 9999) {
      return 'Expires ${month.toString().padLeft(2, '0')}/${(year % 100).toString().padLeft(2, '0')}';
    }
    return 'Test card';
  }

  Widget _brand(Map<String, dynamic> card) {
    final brand = '${card['brand'] ?? ''}'.toLowerCase();
    return Container(
      width: 42,
      height: 30,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF4)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: {'visa', 'mastercard'}.contains(brand)
          ? SvgPicture.asset(
              'assets/icons/payment/$brand.svg',
              fit: BoxFit.contain,
              colorFilter: brand == 'visa'
                  ? const ColorFilter.mode(Color(0xFF1434CB), BlendMode.srcIn)
                  : null,
            )
          : const Icon(
              Icons.credit_card_rounded,
              color: CustomerColors.action,
              size: 24,
            ),
    );
  }

  Future<void> _addCard() async {
    await widget.onAddCard();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Text(
                      'Select Payment Method',
                      style: TextStyle(
                        fontFamily: CustomerTypography.family,
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Close saved cards',
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F3F8),
                    foregroundColor: _ink,
                    minimumSize: const Size(40, 40),
                  ),
                  icon: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a saved card or add a new one.',
              style: TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 12,
                height: 1.4,
                color: _muted,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Saved Cards',
              style: TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              TextButton(
                onPressed: _load,
                child: const Text('Retry saved cards'),
              ),
            ],
            if (!_loading && _error == null && _cards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No saved cards yet.',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            RadioGroup<int>(
              groupValue: _selected,
              onChanged: (value) => setState(() => _selected = value),
              child: Column(
                children: [
                  for (final card in _cards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: _selected == card['methodId']
                            ? const Color(0xFFF0FBFC)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: BorderSide(
                            color: _selected == card['methodId']
                                ? const Color(0xFF27BBC5)
                                : const Color(0xFFE4E9F3),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: RadioListTile<int>(
                          key: ValueKey(
                            'booking-saved-card-${card['methodId']}',
                          ),
                          value: card['methodId'] as int,
                          enabled: !_loading && _error == null,
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                          activeColor: CustomerColors.action,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          title: LayoutBuilder(
                            builder: (context, bounds) {
                              final largeText =
                                  MediaQuery.textScalerOf(context).scale(13) >
                                  19;
                              final details = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _cardTitle(card),
                                    style: const TextStyle(
                                      fontFamily: CustomerTypography.family,
                                      fontSize: 13,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _cardSubtitle(card),
                                    style: const TextStyle(
                                      fontFamily: CustomerTypography.family,
                                      fontSize: 11,
                                      height: 1.3,
                                      color: _muted,
                                    ),
                                  ),
                                  if (card['isDefault'] == true) ...[
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDDF6F5),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: const Text(
                                        'Default',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: CustomerColors.action,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                              if (bounds.maxWidth < 140 || largeText) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _brand(card),
                                    const SizedBox(height: 8),
                                    details,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  _brand(card),
                                  const SizedBox(width: 10),
                                  Expanded(child: details),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE8ECF4))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFE8ECF4))),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Add New Card',
              style: TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
                side: const BorderSide(color: Color(0xFFE4E9F3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('booking-add-new-card'),
                onTap: _loading ? null : _addCard,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6FAF8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: CustomerColors.action,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Card',
                              style: TextStyle(
                                fontFamily: CustomerTypography.family,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Save your card for faster payments',
                              style: TextStyle(
                                fontFamily: CustomerTypography.family,
                                fontSize: 10,
                                height: 1.3,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _ink,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const ValueKey('booking-use-selected-card'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                backgroundColor: CustomerColors.action,
                textStyle: const TextStyle(
                  fontFamily: CustomerTypography.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _loading || _error != null || _selected == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      _cards.singleWhere((m) => m['methodId'] == _selected),
                    ),
              child: const Text('Use Selected Card'),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_outlined, size: 13, color: _muted),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Test cards only',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
