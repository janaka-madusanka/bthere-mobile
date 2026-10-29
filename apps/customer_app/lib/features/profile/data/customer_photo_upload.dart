import 'dart:typed_data';

import 'package:bthere_network/bthere_network.dart';
import 'package:http_parser/http_parser.dart';

import '../../auth/data/customer_auth_service.dart';

Future<String> uploadCustomerPhoto(
  CustomerAuthService auth,
  Uint8List bytes,
  String filename,
) async {
  if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw const CustomerAuthFailure(
      'Choose a profile photo no larger than 10 MB.',
    );
  }
  final mime = customerPhotoMime(bytes);
  if (mime == null) {
    throw const CustomerAuthFailure('Choose a JPG, PNG or WebP photo.');
  }
  final response = await auth.uploadImage(
    FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(mime),
      ),
    }),
  );
  final body = response.data;
  if (response.statusCode != 201 || body is! Map || body['url'] is! String) {
    throw const FormatException('Invalid photo upload response');
  }
  final url = body['url'] as String;
  final uri = Uri.tryParse(url);
  if (url.length > 2048 ||
      uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid public photo URL');
  }
  return url;
}

String? customerPhotoMime(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((e) => bytes[e.key] == e.value)) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}
