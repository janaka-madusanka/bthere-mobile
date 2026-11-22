import '../../discovery/domain/customer_discovery.dart';

class ProviderRatingSummary {
  ProviderRatingSummary(
    this.name,
    this.average,
    this.total,
    this.distribution, {
    this.optionId,
  });
  final String name;
  final num? average;
  final int total;
  final int? optionId;
  final Map<int, int> distribution;
  factory ProviderRatingSummary.parse(Object? raw, {bool option = false}) {
    final value = object(raw);
    final score = value['averageRating'], count = value['totalRatings'];
    if (count is! int ||
        count < 0 ||
        score != null &&
            (score is! num || !score.isFinite || score < 1 || score > 5)) {
      throw const FormatException('Invalid rating summary');
    }
    final bins = object(value['distribution']);
    final distribution = <int, int>{};
    for (var star = 1; star <= 5; star++) {
      final count = bins['$star'];
      if (count is! int || count < 0) {
        throw const FormatException('Invalid rating distribution');
      }
      distribution[star] = count;
    }
    return ProviderRatingSummary(
      option ? text(value['optionName']) : 'All services',
      score,
      count,
      distribution,
      optionId: option ? positiveId(value['optionId']) : null,
    );
  }
}

class ProviderReview {
  ProviderReview(
    this.id,
    this.optionId,
    this.option,
    this.stars,
    this.name,
    this.comment,
    this.date,
  );
  final int id, optionId, stars;
  final String option, name, date;
  final String? comment;
  factory ProviderReview.parse(Object? raw) {
    final value = object(raw);
    final stars = value['rating'], comment = value['comment'];
    if (stars is! int ||
        stars < 1 ||
        stars > 5 ||
        comment != null && comment is! String ||
        value['createdAt'] is! String ||
        DateTime.tryParse(value['createdAt'] as String) == null) {
      throw const FormatException('Invalid provider review');
    }
    return ProviderReview(
      positiveId(value['ratingId']),
      positiveId(value['optionId']),
      text(value['optionName']),
      stars,
      text(value['customerName']),
      comment as String?,
      (value['createdAt'] as String).split('T').first,
    );
  }
}

class ProviderReviewPage {
  ProviderReviewPage(this.rows, this.number, this.totalPages);
  final List<ProviderReview> rows;
  final int number, totalPages;
}
