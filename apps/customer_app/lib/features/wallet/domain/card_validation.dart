enum CardBrand { visa, mastercard }

/// Local format checks are not issuer verification or payment authorization.
abstract final class CardValidation {
  static const testNumber = '4242424242424242';

  static String digits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  /// Prefix recognition is for the logo, not proof that a card number is valid.
  static CardBrand? brand(String input) {
    final value = digits(input);
    if (value.startsWith('4')) return CardBrand.visa;
    if (RegExp(r'^5[1-5]').hasMatch(value)) return CardBrand.mastercard;
    if (value.length >= 4) {
      final prefix = int.parse(value.substring(0, 4));
      if (prefix >= 2221 && prefix <= 2720) return CardBrand.mastercard;
    }
    return null;
  }

  static String? name(String input) {
    final value = input.trim();
    if (value.isEmpty) return 'Enter the name on the card.';
    if (value.runes.length > 70 ||
        !RegExp(r"^[\p{L}\p{M} .’'-]+$", unicode: true).hasMatch(value) ||
        !RegExp(r'\p{L}', unicode: true).hasMatch(value)) {
      return 'Enter a valid cardholder name.';
    }
    return null;
  }

  static String? number(String input) {
    if (input.trim().isEmpty) return 'Enter the card number.';
    if (!RegExp(r'^[0-9 -]+$').hasMatch(input)) {
      return 'Use digits for the card number.';
    }
    final value = digits(input);
    final detected = brand(value);
    final visa =
        detected == CardBrand.visa && [13, 16, 19].contains(value.length);
    final master = detected == CardBrand.mastercard && value.length == 16;
    if (!visa && !master) return 'Enter a valid Visa or Mastercard number.';
    var sum = 0;
    for (var i = value.length - 1; i >= 0; i--) {
      var digit = int.parse(value[i]);
      if ((value.length - 1 - i).isOdd) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    return sum % 10 == 0 ? null : 'Check the card number.';
  }

  static String? expiry(String input, DateTime now) {
    final match = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(input.trim());
    if (match == null) return 'Use MM/YY.';
    final month = int.parse(match[1]!);
    if (month < 1 || month > 12) return 'Enter a month from 01 to 12.';
    final year = (now.year ~/ 100) * 100 + int.parse(match[2]!);
    if (year < now.year || year == now.year && month < now.month) {
      return 'This card has expired.';
    }
    return null; // Valid through the end of the printed expiry month.
  }

  static String? cvv(String input) => RegExp(r'^\d{3}$').hasMatch(input)
      ? null
      : 'Enter the 3-digit security code.';
}
