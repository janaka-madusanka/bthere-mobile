final class ProviderServiceType {
  const ProviderServiceType({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.icon,
    this.coverImage,
    this.gallery = const [],
    this.responsibilities = const [],
    required this.status,
  });
  final int id;
  final String name, status;
  final String? description, iconUrl;
  final ProviderServiceMedia? icon, coverImage;
  final List<ProviderServiceMedia> gallery;
  final List<ProviderServiceResponsibility> responsibilities;
  Uri? get usableIconUri {
    final uri = icon?.usableUri ?? Uri.tryParse(iconUrl ?? '');
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  Uri? get usableCoverUri => coverImage?.usableUri;
}

final class ProviderServiceMedia {
  const ProviderServiceMedia({
    required this.key,
    required this.url,
    this.altText,
    required this.displayOrder,
  });
  final String key, url;
  final String? altText;
  final int displayOrder;
  Uri? get usableUri {
    final uri = Uri.tryParse(url);
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }
}

final class ProviderServiceResponsibility {
  const ProviderServiceResponsibility({
    required this.responsibleParty,
    required this.title,
    this.description,
    required this.required,
    required this.displayOrder,
  });
  final String responsibleParty, title;
  final String? description;
  final bool required;
  final int displayOrder;
}
