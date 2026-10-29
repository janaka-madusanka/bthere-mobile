import '../../../app/customer_theme.dart';

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import 'booking_choice_tiles.dart';

class BookingDynamicField extends StatefulWidget {
  const BookingDynamicField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    required this.controller,
    this.enabled = true,
    this.reusable = false,
    this.compact = false,
    this.showDescription = true,
  });
  final BookingField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final CustomerBookingController controller;
  final bool enabled, reusable, compact, showDescription;
  @override
  State<BookingDynamicField> createState() => _BookingDynamicFieldState();
}

class _BookingDynamicFieldState extends State<BookingDynamicField> {
  late final _text = TextEditingController(
    text: widget.value == null ? '' : '${widget.value}',
  );
  Object? _last;
  String? _error;
  bool _uploading = false;
  @override
  void didUpdateWidget(BookingDynamicField old) {
    super.didUpdateWidget(old);
    if (!const DeepCollectionEquality().equals(old.value, widget.value) &&
        !const DeepCollectionEquality().equals(_last, widget.value)) {
      _text.text = widget.value == null ? '' : '${widget.value}';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _emit(Object? value) {
    _last = value;
    widget.onChanged(value);
  }

  Future<void> _pick() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final existing = widget.value is Map
          ? (widget.value as Map)['files']
          : null;
      final files = existing is List
          ? List<Object?>.from(existing)
          : <Object?>[];
      if (widget.field.maxFiles != null &&
          files.length >= widget.field.maxFiles!) {
        throw const BookingProblem(
          'Remove an existing file before adding another.',
        );
      }
      final key = await widget.controller.chooseUpload(widget.field, () async {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        );
        if (file == null || !mounted) return null;
        final limit = widget.field.maxMb.clamp(1, 100) * 1024 * 1024;
        final length = await file.length();
        if (length != null && length > limit) {
          throw const BookingProblem(
            'This file exceeds the configured size limit.',
          );
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.readAsByteStream()) {
          if (builder.length + chunk.length > limit) {
            throw const BookingProblem(
              'This file exceeds the configured size limit.',
            );
          }
          builder.add(chunk);
        }
        return (builder.takeBytes(), file.name);
      });
      if (key == null) return;
      if (mounted) {
        _emit({
          'files': [
            ...files,
            {'key': key},
          ],
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is BookingProblem
              ? e.message
              : 'Unable to upload the file. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _view(String key) async {
    try {
      final url = await widget.controller.repository.view(key);
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Unable to open');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to open this document. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field, enabled = widget.enabled && !_uploading;
    Widget input;
    if (f.upload) {
      final raw = widget.value is Map ? (widget.value as Map)['files'] : null;
      final files = raw is List ? raw : const [];
      input = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < files.length; i++)
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _view((files[i] as Map)['key'] as String),
                    icon: const Icon(Icons.description_outlined),
                    label: Text('View file ${i + 1}'),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove file ${i + 1}',
                  onPressed: enabled
                      ? () => _emit({
                          'files': [
                            for (var j = 0; j < files.length; j++)
                              if (j != i) files[j],
                          ],
                        })
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          OutlinedButton.icon(
            onPressed: enabled ? _pick : null,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: const Text('Add document'),
          ),
          Text(
            '${f.minFiles} minimum${f.maxFiles == null ? '' : ' · ${f.maxFiles} maximum'} · up to ${f.maxMb.clamp(1, 100)} MB each${f.fileTypes.isEmpty ? '' : ' · ${f.fileTypes.join(', ')}'}',
            style: const TextStyle(color: catalogMuted, fontSize: 12),
          ),
        ],
      );
    } else if (widget.compact &&
        (f.type == 'BOOLEAN' ||
            ({'SELECT', 'MULTI_SELECT'}.contains(f.type) &&
                f.options.length <= 6))) {
      final boolean = f.type == 'BOOLEAN';
      final multiple = f.type == 'MULTI_SELECT';
      const equality = DeepCollectionEquality();
      input = BookingChoiceTiles(
        choices: boolean
            ? const [
                {'value': 'true', 'label': 'Yes'},
                {'value': 'false', 'label': 'No'},
              ]
            : [
                for (var i = 0; i < f.options.length; i++)
                  {'value': '$i', 'label': f.choiceLabel(f.options[i])},
              ],
        selected: boolean
            ? {if (widget.value is bool) '${widget.value}'}
            : {
                for (var i = 0; i < f.options.length; i++)
                  if (multiple
                      ? (widget.value is List &&
                            (widget.value as List).any(
                              (v) => equality.equals(
                                v,
                                f.choiceValue(f.options[i]),
                              ),
                            ))
                      : equality.equals(
                          widget.value,
                          f.choiceValue(f.options[i]),
                        ))
                    '$i',
              },
        enabled: enabled,
        onChanged: (token, selected) {
          if (boolean) {
            _emit(selected ? token == 'true' : null);
          } else {
            final value = f.choiceValue(f.options[int.parse(token)]);
            if (!multiple) {
              _emit(selected ? value : null);
            } else {
              final values = widget.value is List
                  ? [...widget.value as List]
                  : <Object?>[];
              values.removeWhere((v) => equality.equals(v, value));
              if (selected) values.add(value);
              _emit(values);
            }
          }
        },
      );
    } else if (f.type == 'BOOLEAN') {
      input = Wrap(
        spacing: 10,
        children: [
          for (final v in [true, false])
            ChoiceChip(
              label: Text(v ? 'Yes' : 'No'),
              selected: widget.value == v,
              onSelected: enabled ? (_) => _emit(v) : null,
            ),
        ],
      );
    } else if (f.type == 'SELECT') {
      final selected = f.options.indexWhere(
        (c) => const DeepCollectionEquality().equals(
          f.choiceValue(c),
          widget.value,
        ),
      );
      input = DropdownButtonFormField<int>(
        key: ValueKey('${f.id}/$selected'),
        initialValue: selected < 0 ? null : selected,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'Select an option'),
        items: [
          for (var i = 0; i < f.options.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text(f.choiceLabel(f.options[i])),
            ),
        ],
        onChanged: enabled
            ? (i) {
                if (i != null) _emit(f.choiceValue(f.options[i]));
              }
            : null,
      );
    } else if (f.type == 'MULTI_SELECT') {
      final selected = widget.value is List
          ? List<Object?>.from(widget.value as List)
          : <Object?>[];
      input = Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final choice in f.options)
            FilterChip(
              label: Text(f.choiceLabel(choice)),
              selected: selected.any(
                (v) => const DeepCollectionEquality().equals(
                  v,
                  f.choiceValue(choice),
                ),
              ),
              onSelected: enabled
                  ? (on) {
                      final next = [...selected];
                      if (on) {
                        next.add(f.choiceValue(choice));
                      } else {
                        next.removeWhere(
                          (v) => const DeepCollectionEquality().equals(
                            v,
                            f.choiceValue(choice),
                          ),
                        );
                      }
                      _emit(next);
                    }
                  : null,
            ),
        ],
      );
    } else {
      input = TextFormField(
        key: ValueKey(
          'booking-input-${widget.reusable ? 'requirement' : 'field'}-${f.id}',
        ),
        controller: _text,
        style: widget.compact ? const TextStyle(fontSize: 14) : null,
        enabled: enabled,
        maxLines: f.type == 'TEXTAREA' ? 3 : 1,
        keyboardType: switch (f.type) {
          'NUMBER' => const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          'EMAIL' => TextInputType.emailAddress,
          'PHONE' => TextInputType.phone,
          _ => TextInputType.text,
        },
        decoration: InputDecoration(
          isDense: widget.compact,
          filled: widget.compact,
          fillColor: widget.compact ? const Color(0xFFF8FAFB) : null,
          contentPadding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 7)
              : null,
          hintText: switch (f.type) {
            'DATE' => 'YYYY-MM-DD',
            'TIME' => 'HH:mm:ss',
            _ => widget.compact ? 'Enter ${f.label.toLowerCase()}' : null,
          },
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (_) => f.validate(widget.value, reusable: widget.reusable),
        onChanged: (value) =>
            _emit(f.type == 'NUMBER' ? (num.tryParse(value) ?? value) : value),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            f.label,
            style: TextStyle(
              color: widget.compact ? catalogMuted : catalogInk,
              fontWeight: FontWeight.w600,
              fontSize: widget.compact ? 12 : 15,
            ),
          ),
          if (widget.showDescription && f.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                f.description!,
                style: const TextStyle(color: catalogMuted, fontSize: 12),
              ),
            ),
          SizedBox(height: widget.compact ? 4 : 7),
          input,
          if (_error != null)
            Text(_error!, style: const TextStyle(color: CustomerColors.error)),
        ],
      ),
    );
  }
}
