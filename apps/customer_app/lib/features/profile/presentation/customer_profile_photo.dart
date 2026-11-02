import '../../../app/customer_theme.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays profile photos only from the returned server URL.
/// No authorization headers, image URLs or personal values are logged.
class CustomerProfilePhoto extends StatefulWidget {
  const CustomerProfilePhoto({
    super.key,
    required this.url,
    required this.uploading,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });
  final String? url;
  final bool uploading, enabled;
  final VoidCallback onPick, onRemove;
  @override
  State<CustomerProfilePhoto> createState() => _CustomerProfilePhotoState();
}

class _CustomerProfilePhotoState extends State<CustomerProfilePhoto> {
  String? _error;
  int _attempt = 0;
  @override
  void didUpdateWidget(CustomerProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _attempt++;
      _error = null;
    }
  }

  void _reportFailure(Object error, int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt || _error != null) return;
      if (kDebugMode) {
        final status = error is NetworkImageLoadException
            ? error.statusCode
            : null;
        debugPrint(
          'Customer profile photo: image_load_failed status=${status ?? 'unavailable'} source=server_image.',
        );
      }
      setState(() {
        _error = 'The server photo could not be displayed. Retry loading it or choose another photo.';
      });
    });
  }

  Widget get _placeholder =>
      const Icon(Icons.person_rounded, size: 98, color: Color(0xFFB8C3DA));
  Widget _image() {
    final url = widget.url;
    final attempt = _attempt;
    if (url == null) return _placeholder;
    return Image.network(
      url,
      key: ValueKey('customer-profile-photo-remote-$attempt'),
      fit: BoxFit.cover,
      frameBuilder: (_, child, frame, _) => frame == null
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : child,
      errorBuilder: (_, error, _) {
        _reportFailure(error, attempt);
        return _placeholder;
      },
    );
  }

  Future<void> _retry() async {
    final url = widget.url;
    final attempt = _attempt;
    if (url == null) return;
    await NetworkImage(url).evict();
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _attempt++;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8EDF5),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14008491),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(child: _image()),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CustomerColors.action,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      key: const ValueKey('customer-profile-photo'),
                      tooltip: widget.url == null
                          ? 'Add profile photo'
                          : 'Change profile photo',
                      onPressed: widget.enabled ? widget.onPick : null,
                      icon: widget.uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 23,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.url == null
              ? 'Add a profile photo (optional)'
              : 'Change your profile photo',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: const Color(0xFF687B83)),
        ),
        const SizedBox(height: 4),
        Text(
          'JPG, PNG or WebP · Up to 10 MB',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: const Color(0xFF687B83)),
        ),
        if (widget.url != null)
          Center(
            child: TextButton(
              onPressed: widget.enabled ? widget.onRemove : null,
              child: const Text('Remove photo'),
            ),
          ),
        if (_error case final error?) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              key: const ValueKey('customer-profile-photo-load-error'),
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
          Center(
            child: TextButton(
              key: const ValueKey('customer-profile-photo-retry'),
              onPressed: widget.enabled ? _retry : null,
              child: const Text('Retry photo'),
            ),
          ),
        ],
      ],
    );
  }
}
