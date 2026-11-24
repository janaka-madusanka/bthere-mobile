import '../../discovery/domain/customer_discovery.dart';
import '../../wallet/data/customer_wallet_repository.dart';

class BookingCancellation {
  BookingCancellation(this.data);
  final Map<String, dynamic> data;
  num get refund => data['refundAmount'] as num;
  String money(String field) =>
      '${data['currencyCode']} ${walletMoney(data[field]).replaceFirst('Rs. ', '')}';
  factory BookingCancellation.parse(
    Object? raw,
    int jobId, {
    bool receipt = false,
  }) {
    final value = object(raw);
    if (value['jobId'] != jobId ||
        !{
          'CUSTOMER',
          'PROVIDER',
          'SYSTEM',
          'CUSTOMER_NO_SHOW',
          'NO_SHOW_REJECTED',
        }.contains(value['cancelledBy']) ||
        value['refundDestination'] != 'WALLET') {
      throw const FormatException('Invalid cancellation identity');
    }
    text(value['currencyCode']);
    for (final field in [
      'paidAmount',
      'refundAmount',
      'cancellationFee',
      'retainedAmount',
      'providerAmount',
      'platformAmount',
    ]) {
      final amount = value[field];
      if (amount == null &&
          !['paidAmount', 'refundAmount', 'cancellationFee'].contains(field)) {
        continue;
      }
      if (amount is! num ||
          !amount.isFinite ||
          walletMinorUnits(amount).isNegative) {
        throw const FormatException('Invalid cancellation money');
      }
    }
    if (walletMinorUnits(value['refundAmount']) >
        walletMinorUnits(value['paidAmount'])) {
      throw const FormatException('Invalid refund');
    }
    if (receipt) {
      positiveId(value['cancellationId']);
      if (!{
        'REFUNDED',
        'PARTIALLY_REFUNDED',
        'CANCELLATION_SETTLED',
      }.contains(value['paymentStatus'])) {
        throw const FormatException('Invalid cancellation settlement');
      }
      final penalty = value['penalty'];
      if (penalty != null) {
        final row = object(penalty);
        for (final field in [
          'penaltyAmount',
          'customerShareAmount',
          'customerPaidAmount',
        ]) {
          final amount = row[field];
          if (amount is! num ||
              !amount.isFinite ||
              walletMinorUnits(amount).isNegative) {
            throw const FormatException('Invalid compensation');
          }
        }
        if (walletMinorUnits(row['customerPaidAmount']) >
            walletMinorUnits(row['customerShareAmount'])) {
          throw const FormatException('Invalid credited compensation');
        }
      }
    }
    return BookingCancellation(value);
  }
}
