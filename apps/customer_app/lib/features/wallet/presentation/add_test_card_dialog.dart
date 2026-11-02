import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';
import '../domain/card_validation.dart';

/// MOCK setup accepts no card data. None of these fields leave this widget.
class AddTestCardDialog extends StatefulWidget {
  const AddTestCardDialog({
    super.key,
    required this.now,
    required this.onAdd,
    this.unavailableReason,
  });
  final DateTime Function() now;
  final Future<bool> Function() onAdd;
  final String? unavailableReason;
  @override
  State<AddTestCardDialog> createState() => _AddTestCardDialogState();
}

class _AddTestCardDialogState extends State<AddTestCardDialog>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _number = TextEditingController(),
      _expiry = TextEditingController(),
      _cvv = TextEditingController();
  bool _showCvv = false, _submitted = false, _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _clear() {
    _name.clear();
    _number.clear();
    _expiry.clear();
    _cvv.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _clear();
      if (mounted) {
        setState(() {
          _showCvv = false;
          _submitted = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clear();
    _name.dispose();
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_working || widget.unavailableReason != null) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _working = true);
    // Erase inputs before calling the no-body MOCK endpoint.
    _clear();
    var added = false;
    try {
      added = await widget.onAdd();
    } catch (_) {
      /* No raw input in errors. */
    }
    if (!mounted) return;
    if (added) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _working = false;
      _submitted = false;
      _error = 'The test card could not be confirmed. Refresh your wallet before trying again.';
    });
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String key,
    String? Function(String) validate,
    IconData icon, {
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    bool secret = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: CustomerColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        key: ValueKey(key),
        controller: controller,
        autovalidateMode: _submitted && !_working
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        enabled: !_working,
        keyboardType: keyboard,
        textInputAction: secret ? TextInputAction.done : TextInputAction.next,
        inputFormatters: formatters,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        obscureText: secret && !_showCvv,
        maxLength: key == 'cardholder-name' ? 70 : null,
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) => null,
        validator: (value) => validate(value ?? ''),
        onFieldSubmitted: secret ? (_) => _add() : null,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: CustomerColors.background,
          prefixIcon: Icon(icon, color: CustomerColors.action, size: 21),
          suffixIcon: secret
              ? IconButton(
                  tooltip: _showCvv
                      ? 'Hide security code'
                      : 'Show security code',
                  onPressed: _working
                      ? null
                      : () => setState(() => _showCvv = !_showCvv),
                  icon: Icon(
                    _showCvv
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                )
              : key == 'card-number'
              ? ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _number,
                  builder: (_, value, _) {
                    final brand = CardValidation.brand(value.text);
                    if (brand == null) return const SizedBox.shrink();
                    return Padding(
                      key: ValueKey('card-brand-${brand.name}'),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: SvgPicture.asset(
                          'assets/icons/payment/${brand.name}.svg',
                          width: 40,
                          height: 26,
                          fit: BoxFit.contain,
                          colorFilter: brand == CardBrand.visa
                              ? const ColorFilter.mode(
                                  Color(0xFF1434CB),
                                  BlendMode.srcIn,
                                )
                              : null,
                          semanticsLabel: brand == CardBrand.visa
                              ? 'Visa'
                              : 'Mastercard',
                        ),
                      ),
                    );
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          errorMaxLines: 3,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_working,
    child: Dialog(
      backgroundColor: CustomerColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            autovalidateMode: _submitted && !_working
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add New Card',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: CustomerColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close add card',
                      onPressed: _working ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Test mode',
                  style: TextStyle(
                    fontSize: 12,
                    color: CustomerColors.secondaryText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  'Cardholder Name',
                  _name,
                  'cardholder-name',
                  CardValidation.name,
                  Icons.person_outline,
                  hint: 'Name on test card',
                  keyboard: TextInputType.name,
                ),
                const SizedBox(height: 14),
                _field(
                  'Card Number',
                  _number,
                  'card-number',
                  (value) {
                    final error = CardValidation.number(value);
                    if (error != null) return error;
                    return CardValidation.digits(value) ==
                            CardValidation.testNumber
                        ? null
                        : 'Use test number 4242 4242 4242 4242. Real cards cannot be linked yet.';
                  },
                  Icons.credit_card,
                  hint: '4242 4242 4242 4242',
                  keyboard: TextInputType.number,
                  formatters: [CardNumberInputFormatter()],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, bounds) {
                    final fields = [
                      _field(
                        'Expiry Date',
                        _expiry,
                        'card-expiry',
                        (value) => CardValidation.expiry(value, widget.now()),
                        Icons.calendar_month_outlined,
                        hint: 'MM/YY',
                        keyboard: TextInputType.number,
                        formatters: [CardExpiryInputFormatter()],
                      ),
                      _field(
                        'CVV',
                        _cvv,
                        'card-cvv',
                        CardValidation.cvv,
                        Icons.lock_outline,
                        hint: '123',
                        keyboard: TextInputType.number,
                        secret: true,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                      ),
                    ];
                    return bounds.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(13) > 18
                        ? Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 14),
                              fields[1],
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: fields[0]),
                              const SizedBox(width: 12),
                              Expanded(child: fields[1]),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 14),
                if (widget.unavailableReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      widget.unavailableReason!,
                      style: const TextStyle(
                        color: CustomerColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: CustomerColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('submit-test-card'),
                  onPressed:
                      _working ||
                          _error != null ||
                          widget.unavailableReason != null
                      ? null
                      : _add,
                  child: _working
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add test card'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = CardValidation.digits(newValue.text);
    if (digits.length > 19) return oldValue;
    final cursor = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final before = CardValidation.digits(newValue.text.substring(0, cursor))
        .length;
    final formatted = [
      for (var i = 0; i < digits.length; i += 4)
        digits.substring(i, (i + 4).clamp(0, digits.length)),
    ].join(' ');
    final position = (before + (before == 0 ? 0 : (before - 1) ~/ 4)).clamp(
      0,
      formatted.length,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: position),
    );
  }
}

class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = CardValidation.digits(newValue.text);
    if (digits.length > 4) return oldValue;
    final cursor = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final before = CardValidation.digits(newValue.text.substring(0, cursor))
        .length;
    final formatted = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: (before + (before > 2 ? 1 : 0)).clamp(0, formatted.length),
      ),
    );
  }
}
