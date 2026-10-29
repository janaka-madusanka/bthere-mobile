import '../../auth/data/customer_auth_service.dart';
import '../domain/customer_profile.dart';

class CustomerProfileRepository {
  CustomerProfileRepository(this.auth);
  final CustomerAuthService auth;
  Future<CustomerProfile?> load() async {
    try {
      final response = await auth.get('/customers/me/profile');
      if (response.statusCode != 200) {
        throw const FormatException('Invalid profile response');
      }
      return CustomerProfile.fromJson(response.data);
    } on CustomerAuthFailure catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  Future<CustomerProfile> save(CustomerProfileInput input) async {
    if (!input.valid) {
      throw const CustomerAuthFailure('Please check your profile details.');
    }
    final response = await auth.put('/customers/me/profile', input.toJson());
    if (response.statusCode != 200) {
      throw const FormatException('Invalid profile response');
    }
    return CustomerProfile.fromJson(response.data);
  }
}
