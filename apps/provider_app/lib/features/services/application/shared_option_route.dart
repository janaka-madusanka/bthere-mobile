import '../../../app/router/app_routes.dart';
import '../domain/service_registration.dart';

/// Navigate to the option's existing workflow, never the source catalog page.
String sharedOptionRoute(
  SharedOptionRegistration source, {
  bool incomplete = false,
}) {
  final serviceId = source.registrationServiceTypeId;
  if (source.verificationStatus == 'APPROVED' &&
      source.providerStatus != 'INACTIVE' &&
      source.adminStatus != 'INACTIVE') {
    return AppRoutes.subServiceProfile(serviceId, source.optionId);
  }
  if (incomplete) {
    return '/services/$serviceId/register?optionId=${source.optionId}&details=1';
  }
  return AppRoutes.serviceStatus(serviceId);
}
