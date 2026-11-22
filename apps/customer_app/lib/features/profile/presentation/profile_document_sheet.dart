import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/customer_theme.dart';
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

  String get query {
    final services = widget.document['services'] as List;
    final scope = services.where((s) => s['serviceTypeId'] is int).firstOrNull;
    return scope == null
        ? ''
        : '?serviceTypeId=${scope['serviceTypeId']}${scope['optionId'] is int ? '&optionId=${scope['optionId']}' : ''}';
  }

  Future<void> load() async {
    if (!mounted || !alive) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await ref
          .read(customerBookingRepositoryProvider)
          .request('GET', '/customers/me/requirements$query');
      if (!mounted || !alive) return;
      final result = (raw as List)
          .map(CustomerRequirement.parse)
          .where((r) => r.field.id == widget.document['requirementId'])
          .first;
      if (!result.field.upload) {
        throw const FormatException('Not an upload requirement');
      }
      setState(() {
        requirement = result;
        files.clear();
        final value = result.value;
        if (value is Map && value['files'] is List) {
          files.addAll(
            (value['files'] as List).map((f) => {'key': f['key'] as String}),
          );
        }
        expiry.text = result.expires ?? '';
      });
    } catch (_) {
      if (mounted && alive) {
        setState(() => error = 'Document requirements could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get underReview => requirement?.status == 'PENDING';

  Future<void> pick() async {
    if (!alive || busy || underReview || requirement == null) return;
    final field = requirement!.field;
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
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
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
      if (alive) setState(() => files.add({'key': key}));
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
    if (!alive || busy || uncertain || underReview || requirement == null) {
      return;
    }
    final value = {
      'files': files.map((f) => {'key': f['key']!}).toList(),
    };
    final issue = requirement!.field.validate(value, reusable: true);
    final date = expiry.text.trim();
    final parsed = date.isEmpty ? null : DateTime.tryParse(date);
    final today = DateUtils.dateOnly(DateTime.now());
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
    try {
      final url = await ref.read(customerBookingRepositoryProvider).view(key);
      if (mounted && alive) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (alive) setState(() => error = 'Document could not be opened.');
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File requirements',
                    style: CustomerTypography.compactStrong.copyWith(
                      color: CustomerColors.action,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Allowed formats: ${requirement!.field.fileTypes.isEmpty ? 'Supported document files' : requirement!.field.fileTypes.join(', ')}. Maximum ${requirement!.field.maxMb} MB per file.',
                    style: CustomerTypography.compact,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    underReview
                        ? 'Under review. Booking is available after the required approval.'
                        : 'Replacing documents may require a new review.',
                    style: CustomerTypography.compact.copyWith(
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                        child: Text(
                          'View document ${i + 1}',
                          style: CustomerTypography.compactStrong,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove document',
                      onPressed: busy || uncertain || underReview
                          ? null
                          : () => setState(() => files.removeAt(i)),
                      icon: const Icon(Icons.close_rounded, size: 20),
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF1FBFA),
                foregroundColor: CustomerColors.action,
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Color(0xFFB6E3DF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: busy || uncertain || underReview ? null : pick,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Upload document'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: expiry,
              enabled: !busy && !uncertain && !underReview,
              decoration: InputDecoration(
                labelText: 'Expiry date (optional)',
                hintText: 'YYYY-MM-DD',
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: busy || uncertain || underReview ? null : save,
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
