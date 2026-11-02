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

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: CustomerColors.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close saved cards',
                onPressed: _loading ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Text(
            'Choose a saved card or add a new one.',
            style: TextStyle(fontSize: 12, color: CustomerColors.secondaryText),
          ),
          const SizedBox(height: 16),
          const Text(
            'Saved Cards',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
              style: const TextStyle(
                color: CustomerColors.secondaryText,
                fontSize: 12,
              ),
            ),
            TextButton(
              onPressed: _load,
              child: const Text('Retry saved cards'),
            ),
          ],
          if (!_loading && _error == null && _cards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No saved cards yet.',
                style: TextStyle(
                  fontSize: 12,
                  color: CustomerColors.secondaryText,
                ),
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
                    child: RadioListTile<int>(
                      key: ValueKey('booking-saved-card-${card['methodId']}'),
                      value: card['methodId'] as int,
                      enabled: !_loading && _error == null,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      selected: _selected == card['methodId'],
                      selectedTileColor: const Color(0xFFEAF9F9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _selected == card['methodId']
                              ? CustomerColors.action
                              : CustomerColors.border,
                        ),
                      ),
                      title: Text(
                        card['displayLabel'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Test card',
                        style: TextStyle(fontSize: 11),
                      ),
                      secondary:
                          {
                            'visa',
                            'mastercard',
                          }.contains('${card['brand']}'.toLowerCase())
                          ? SvgPicture.asset(
                              'assets/icons/payment/${'${card['brand']}'.toLowerCase()}.svg',
                              width: 32,
                              height: 22,
                            )
                          : const Icon(
                              Icons.credit_card,
                              color: CustomerColors.action,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    fontSize: 11,
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          OutlinedButton.icon(
            key: const ValueKey('booking-add-new-card'),
            onPressed: _loading
                ? null
                : () async {
                    await widget.onAddCard();
                    if (mounted) await _load();
                  },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add New Card'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const ValueKey('booking-use-selected-card'),
            onPressed: _loading || _error != null || _selected == null
                ? null
                : () => Navigator.pop(
                    context,
                    _cards.singleWhere((m) => m['methodId'] == _selected),
                  ),
            child: const Text('Use Selected Card'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Test cards only. Live card checkout is completed separately after provider acceptance.',
            style: TextStyle(fontSize: 10, color: CustomerColors.secondaryText),
          ),
        ],
      ),
    ),
  );
}
