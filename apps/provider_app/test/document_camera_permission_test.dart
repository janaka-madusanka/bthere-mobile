import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';

class RecordingPicker extends ImagePicker {
  int calls = 0;
  CameraDevice? camera;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    camera = preferredCameraDevice;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  for (final selfie in [true, false]) {
    test('requests permission before opening camera, selfie=$selfie', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'checkPermissionStatus') return 0;
        if (call.method == 'requestPermissions') return <int, int>{1: 1};
        return null;
      });
      final picker = RecordingPicker();
      expect(
        await NativeDocumentCamera(picker: picker).capture(selfie: selfie),
        isNull,
      );
      expect(calls, ['checkPermissionStatus', 'requestPermissions']);
      expect(picker.calls, 1);
      expect(picker.camera, selfie ? CameraDevice.front : CameraDevice.rear);
    });
  }
  for (final status in [0, 4]) {
    test('denied permission $status does not launch capture', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'checkPermissionStatus') return status;
        if (call.method == 'requestPermissions') return <int, int>{1: status};
        return null;
      });
      final picker = RecordingPicker();
      await expectLater(
        NativeDocumentCamera(picker: picker).capture(selfie: false),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            status == 4
                ? 'camera_access_denied_permanently'
                : 'camera_permission_denied',
          ),
        ),
      );
      expect(picker.calls, 0);
    });
  }
  test('already granted permission does not prompt again', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return 1;
    });
    final picker = RecordingPicker();
    await NativeDocumentCamera(picker: picker).capture(selfie: false);
    expect(calls, ['checkPermissionStatus']);
    expect(picker.calls, 1);
  });
}
