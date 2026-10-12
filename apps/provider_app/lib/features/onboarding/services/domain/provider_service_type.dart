final class ProviderServiceType {
  const ProviderServiceType({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.status,
  });
  final int id;
  final String name, status;
  final String? description, iconUrl;
  Uri? get usableIconUri {
    final uri = Uri.tryParse(iconUrl ?? '');
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }
}
