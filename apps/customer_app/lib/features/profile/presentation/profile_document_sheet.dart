import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/customer_theme.dart';
import '../domain/customer_document.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../booking/application/customer_booking_controller.dart';
import '../../booking/domain/booking_models.dart';

class ProfileDocumentSheet extends ConsumerStatefulWidget {
  const ProfileDocumentSheet({
    super.key,
    required this.owner,
    required this.document,
  });
  final int owner;
  final Map<String, dynamic> document;
  @override
  ConsumerState<ProfileDocumentSheet> createState() =>
      _ProfileDocumentSheetState();
}

class _ProfileDocumentSheetState extends ConsumerState<ProfileDocumentSheet> {
  CustomerRequirement? requirement;
  Map<String, dynamic>? currentDocument;
  final files = <Map<String, String>>[];
  final expiry = TextEditingController();
  bool busy = false, loading = true, uncertain = false;
  String? error;
  bool get alive =>
      mounted &&
      ref.read(customerAuthControllerProvider).user?.id == widget.owner &&
      ref.read(customerAuthControllerProvider).stage ==
          CustomerAuthStage.authenticated;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    expiry.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted || !alive) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repository = ref.read(customerBookingRepositoryProvider);
      Object? raw;
      try {
        raw = await repository.request(
          'GET',
          '/customers/me/documents/${widget.document['requirementId']}',
        );
      } on BookingProblem catch (e) {
        if (e.status != 404 && e.status != 405) rethrow;
        // Both endpoints return the same document contract. Some server
        // versions expose the catalogue before the individual GET route.
        Object? catalogue;
        try {
          catalogue = await repository.request(
            'GET',
            '/customers/me/documents',
          );
        } on BookingProblem catch (listError) {
          if (listError.status != 404 && listError.status != 405) rethrow;
          final overview = await repository.request(
            'GET',
            '/customers/me/profile-overview?recentLimit=2',
          );
          if (overview is! Map) rethrow;
          catalogue = overview['documents'];
        }
        if (catalogue is! List) rethrow;
        raw = catalogue.whereType<Map>().firstWhere(
          (item) => item['requirementId'] == widget.document['requirementId'],
        );
      }
      if (!alive) return;
      final item = Map<String, dynamic>.from(raw as Map);
      if (item['requirementId'] != widget.document['requirementId']) {
        throw const FormatException('Document mismatch');
      }
      final result = documentRequirement(item);
      currentDocument = item;
      setState(() {
        requirement = result;
        uncertain = false;
        files.clear();
        final value = result.value;
        if (value is Map && value['files'] is List) {
          files.addAll(
            (value['files'] as List).map((f) => {'key': f['key'] as String}),
          );
        }
        expiry.text = result.expires ?? '';
      });
    } catch (e) {
      debugPrint(
        'Document details: requirement=${widget.document['requirementId']} error=${e.runtimeType} status=${e is BookingProblem ? e.status : '-'}',
      );
      if (mounted && alive) {
        setState(
          () => error = e is BookingProblem
              ? 'Document could not be loaded${e.status == null ? '' : ' (HTTP ${e.status})'}. Please retry.'
              : 'Document information could not be read. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get readOnly => currentDocument?['actionRequired'] != true;

  Future<void> chooseExpiry() async {
    if (!alive || busy || uncertain || readOnly) return;
    final today = DateUtils.dateOnly(
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)),
    );
    final saved = DateTime.tryParse(expiry.text);
    final initial = saved != null && !saved.isBefore(today) ? saved : today;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 100, 12, 31),
      helpText: 'Document expiry date',
    );
    if (selected != null && alive) {
      setState(() => expiry.text = selected.toIso8601String().substring(0, 10));
    }
  }

  Future<void> pick() async {
    if (!alive || busy || readOnly || requirement == null) return;
    final field = requirement!.field;
    if (field.uploadExtensions.isEmpty) {
      setState(
        () => error =
            'This document type is not supported. Please contact support.',
      );
      return;
    }
    if (files.length >= (field.maxFiles ?? 100)) {
      setState(() => error = 'Remove a file before adding another.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: field.uploadExtensions,
      );
      if (file == null || !alive) return;
      final limit = field.maxMb.clamp(1, 100) * 1024 * 1024;
      final length = await file.length();
      if (length != null && length > limit) {
        throw const FormatException('File too large');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (!mounted || !alive) return;
        if (bytes.length + chunk.length > limit) {
          throw const FormatException('File too large');
        }
        bytes.add(chunk);
      }
      if (!mounted || !alive) return;
      final key = await ref
          .read(customerBookingRepositoryProvider)
          .upload(field, bytes.takeBytes(), file.name);
      if (alive && !files.any((file) => file['key'] == key)) {
        setState(
          () => files.add({
            'key': key,
            'name': file.name,
            'size': '${length ?? 0}',
          }),
        );
      }
    } catch (_) {
      if (mounted && alive) {
        setState(
          () => error = 'Unable to upload. Check the file type and size limit.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!alive || busy || uncertain || readOnly || requirement == null) {
      return;
    }
    final value = {
      'files': files.map((f) => {'key': f['key']!}).toList(),
    };
    final issue = requirement!.field.validate(value, reusable: true);
    final date = expiry.text.trim();
    final parsed = date.isEmpty ? null : DateTime.tryParse(date);
    final today = DateUtils.dateOnly(
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)),
    );
    if (issue != null ||
        files.isEmpty ||
        (date.isNotEmpty &&
            (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
                parsed == null ||
                parsed.toIso8601String().substring(0, 10) != date ||
                parsed.isBefore(today)))) {
      setState(
        () => error =
            issue ??
            (files.isEmpty
                ? 'Upload a document first.'
                : 'Enter a valid expiry date today or later.'),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(customerBookingRepositoryProvider).saveRequirements([
        {
          'requirementId': widget.document['requirementId'],
          'value': value,
          'expiresOn': date.isEmpty ? null : date,
        },
      ]);
      if (mounted && alive) Navigator.pop(context, true);
    } catch (e) {
      if (mounted && alive) {
        setState(() {
          uncertain = e is! BookingProblem || (e.status ?? 500) >= 500;
          error = uncertain
              ? 'Save not confirmed. Close and refresh your documents before submitting again.'
              : 'Document could not be saved. Check the requirement and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _viewFile(String key) async {
    if (!alive || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Obtain a fresh signed URL for every attempt; never reuse upload URLs.
      final url = await ref.read(customerBookingRepositoryProvider).view(key);
      if (!alive) return;
      final uri = Uri.parse(url);
      var opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!opened && alive) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!opened) throw StateError('No document viewer available');
    } catch (_) {
      if (alive) {
        setState(
          () => error = 'Document could not be opened. Check your connection and try again.',
        );
      }
    } finally {
      if (alive) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customerAuthControllerProvider);
    if (!alive) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CustomerColors.selection,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.upload_file_outlined,
                  color: CustomerColors.action,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.document['name'] as String,
                      style: CustomerTypography.card.copyWith(
                        color: const Color(0xFF10143F),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Service document',
                      style: CustomerTypography.compact.copyWith(
                        color: CustomerColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loading)
            Container(
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8F7),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          if (requirement != null) ...[
            _DocumentReviewStatus(requirement: requirement!),
            if (documentReason(currentDocument!) case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message, style: CustomerTypography.compact),
              ),
            const SizedBox(height: 12),
            _UploadTips(field: requirement!.field),
            const SizedBox(height: 8),
            Text(
              readOnly
                  ? (requirement!.status == 'PENDING'
                        ? 'Under review. Booking is available after the required approval.'
                        : 'This document is saved and reused for all its services.')
                  : 'Replacing documents may require a new review.',
              style: CustomerTypography.compact.copyWith(
                color: CustomerColors.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            CustomPaint(
              painter: const _UploadBorder(),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFE),
                  foregroundColor: CustomerColors.action,
                  minimumSize: const Size.fromHeight(72),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed:
                    busy ||
                        uncertain ||
                        readOnly ||
                        files.length >= (requirement!.field.maxFiles ?? 20)
                    ? null
                    : pick,
                icon: const Icon(Icons.cloud_upload_outlined, size: 28),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload document',
                      style: CustomerTypography.card,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${requirement!.field.supportedUploadTypes.join(', ')} - Up to ${requirement!.field.maxMb} MB',
                      style: CustomerTypography.compact,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your documents${requirement!.field.maxFiles == null ? '' : ' (${files.length}/${requirement!.field.maxFiles})'}',
              style: CustomerTypography.card,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < files.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: CustomerColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: CustomerColors.action,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: busy
                            ? null
                            : () => _viewFile(files[i]['key']!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              files[i]['name'] ?? 'View document ${i + 1}',
                              style: CustomerTypography.compactStrong,
                            ),
                            if (files[i]['size'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${((int.tryParse(files[i]['size']!) ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB',
                                style: CustomerTypography.compact.copyWith(
                                  color: CustomerColors.secondaryText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove document',
                      onPressed: busy || uncertain || readOnly
                          ? null
                          : () => setState(() => files.removeAt(i)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE9ED),
                        foregroundColor: CustomerColors.error,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Choose a clear, readable file to submit.',
                  style: CustomerTypography.compact.copyWith(
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('document-expiry-date'),
              controller: expiry,
              readOnly: true,
              onTap: chooseExpiry,
              enabled: !busy && !uncertain && !readOnly,
              decoration: InputDecoration(
                labelText: 'Expiry date (optional)',
                hintText: 'YYYY-MM-DD',
                suffixIcon: expiry.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear expiry date',
                        onPressed: busy || uncertain || readOnly
                            ? null
                            : () => setState(expiry.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
                prefixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  color: CustomerColors.action,
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFFAFCFD),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: CustomerColors.action,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: busy || uncertain || readOnly ? null : save,
              child: Text(busy ? 'Please wait...' : 'Submit documents'),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: CustomerTypography.body.copyWith(
                  color: CustomerColors.error,
                ),
              ),
            ),
          if (!loading && requirement == null)
            TextButton(
              onPressed: load,
              child: const Text('Retry requirements'),
            ),
          if (uncertain)
            TextButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reload document status'),
            ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DocumentReviewStatus extends StatelessWidget {
  const _DocumentReviewStatus({required this.requirement});
  final CustomerRequirement requirement;
  @override
  Widget build(BuildContext context) {
    final (label, color, fill, icon) = switch (requirement.status) {
      'APPROVED' => (
        'Approved',
        CustomerColors.success,
        const Color(0xFFE7F7EE),
        Icons.verified_outlined,
      ),
      'PROVIDED' => (
        'Submitted',
        CustomerColors.action,
        CustomerColors.selection,
        Icons.task_alt_rounded,
      ),
      'PENDING' => (
        'Under review',
        CustomerColors.warning,
        const Color(0xFFFFF4DF),
        Icons.schedule_rounded,
      ),
      'REJECTED' => (
        'Rejected - please resubmit',
        CustomerColors.error,
        const Color(0xFFFFECEF),
        Icons.error_outline_rounded,
      ),
      'EXPIRED' => (
        'Expired - please resubmit',
        CustomerColors.error,
        const Color(0xFFFFECEF),
        Icons.event_busy_outlined,
      ),
      _ => (
        'Not submitted',
        CustomerColors.secondaryText,
        const Color(0xFFF0F4F6),
        Icons.upload_file_outlined,
      ),
    };
    return Container(
      key: const ValueKey('document-review-status'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CustomerTypography.card.copyWith(color: color),
                ),
                if (requirement.rejection?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    requirement.rejection!,
                    style: CustomerTypography.compact,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadTips extends StatelessWidget {
  const _UploadTips({required this.field});
  final BookingField field;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE7F8F8), Color(0xFFDDF4F2)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: CustomerColors.action,
                    size: 23,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Upload tips', style: CustomerTypography.card),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final tip in [
                'Use a clear and readable document',
                'Make sure all edges are visible',
                'Allowed formats: ${field.supportedUploadTypes.join(', ')}. Maximum ${field.maxMb} MB per file.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF42AEA8),
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(tip, style: CustomerTypography.compact),
                      ),
                    ],
                  ),
                ),
              Text(
                '${field.minFiles}-${field.maxFiles ?? 20} files. Documents are private.',
                style: CustomerTypography.compact,
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width > 350 &&
            MediaQuery.textScalerOf(context).scale(14) < 20)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Image.asset(
              'assets/illustrations/documents/document_upload_tips.png',
              width: 82,
              height: 82,
              fit: BoxFit.contain,
            ),
          ),
      ],
    ),
  );
}

class _UploadBorder extends CustomPainter {
  const _UploadBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(13)),
      );
    final paint = Paint()
      ..color = const Color(0xFF9CDDD9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 10) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_UploadBorder oldDelegate) => false;
}
