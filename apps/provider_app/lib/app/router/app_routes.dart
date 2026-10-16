abstract final class AppRoutes {
  static const home = '/home';
  static const services = '/services';
  static const requests = '/requests';
  static const messages = '/messages';
  // Account tab is distinct from Provider Details onboarding.
  static const account = '/profile';
  static String serviceDetail(int id) => '$services/$id';
  static String subServiceProfile(int serviceTypeId, int optionId) =>
      '$services/$serviceTypeId/sub-services/$optionId/profile';
  static String serviceSetup(int id, {bool view = false}) =>
      '$services/$id/setup${view ? '?view=1' : ''}';
  static String serviceStatus(int id) => '$services/$id/status';
  // Legacy constants retained for saved-link migration, never the landing flow.
  static const startup = '/';
  static const auth = '/auth';
  static const emailRegistration = '/auth/register/email';
  static const emailVerification = '/auth/verify-email';
  static const onboarding = '/onboarding';
  static const profile = '/onboarding/profile';
  static const market = '/onboarding/market';
  static const service = '/onboarding/service';
  static const serviceRequirements = '/onboarding/service-requirements';
  static const requirementsOptions = '$serviceRequirements/options';
  static const requirementsAvailability = '$serviceRequirements/availability';
  static const requirementsLocations = '$serviceRequirements/locations';
  static const requirementsSkills = '$serviceRequirements/skills';
  static const requirementsDocuments = '$serviceRequirements/documents';
  static const requirementsCertificates = '$serviceRequirements/certificates';
  static const requirementsEducation = '$serviceRequirements/education';
  static const requirementsAdditional = '$serviceRequirements/additional';
  static const review = '/onboarding/review';
}
