import 'package:flutter/foundation.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../data/customer_booking_repository.dart';
import '../domain/provider_reviews.dart';

class CustomerProviderReviewsController extends ChangeNotifier {
  CustomerProviderReviewsController(
    this.repository,
    this.auth,
    this.providerId,
    this.optionId,
  ) : owner = auth.user?.id {
    auth.addListener(identityChanged);
  }
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final int providerId;
  final int? owner;
  int? optionId;
  List<ProviderRatingSummary> summaries = [];
  List<ProviderReview> reviews = [];
  String? summaryError, reviewError;
  bool summaryLoading = false, reviewLoading = false;
  bool disposed = false, lost = false;
  int revision = 0, nextPage = 0;
  bool hasMore = false;
  bool get alive =>
      !disposed &&
      !lost &&
      owner != null &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  void emit() {
    if (!disposed) notifyListeners();
  }

  void identityChanged() {
    if (!alive) {
      lost = true;
      revision++;
      summaries = [];
      reviews = [];
      summaryError = reviewError = null;
      emit();
    }
  }

  Future<void> loadSummary() async {
    if (!alive || summaryLoading) return;
    summaryLoading = true;
    summaryError = null;
    emit();
    try {
      final result = await repository.providerRatings(providerId);
      if (alive) summaries = result;
    } catch (_) {
      if (alive) summaryError = 'Rating summary could not be loaded.';
    } finally {
      if (alive) {
        summaryLoading = false;
        emit();
      }
    }
  }

  Future<void> select(int? id) async {
    if (!alive || optionId == id) return;
    optionId = id;
    revision++;
    reviewLoading = false;
    reviews = [];
    nextPage = 0;
    hasMore = false;
    await loadReviews();
  }

  Future<void> loadReviews() async {
    if (!alive || reviewLoading) return;
    final ticket = revision, scope = optionId, page = nextPage;
    reviewLoading = true;
    reviewError = null;
    emit();
    try {
      final result = await repository.providerReviews(
        providerId,
        optionId: scope,
        page: page,
      );
      if (!alive || ticket != revision) return;
      final seen = reviews.map((r) => r.id).toSet();
      reviews = [...reviews, ...result.rows.where((r) => seen.add(r.id))];
      nextPage = page + 1;
      hasMore = nextPage < result.totalPages;
    } catch (_) {
      if (alive && ticket == revision) {
        reviewError = 'Reviews could not be loaded.';
      }
    } finally {
      if (alive && ticket == revision) {
        reviewLoading = false;
        emit();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    revision++;
    auth.removeListener(identityChanged);
    super.dispose();
  }
}
