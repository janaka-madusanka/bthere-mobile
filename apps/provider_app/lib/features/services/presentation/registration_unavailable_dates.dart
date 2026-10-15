import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/registration_repository.dart';
import 'registration_widgets.dart';

class RegistrationUnavailableDates extends ConsumerStatefulWidget {
  const RegistrationUnavailableDates({required this.assignmentId, super.key});
  final int assignmentId;
  @override
  ConsumerState<RegistrationUnavailableDates> createState() => _DatesState();
}

class _DatesState extends ConsumerState<RegistrationUnavailableDates> {
  List<Map<String, dynamic>> dates = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final result = await ref
        .read(registrationRepositoryProvider)
        .unavailableDates(widget.assignmentId);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (result case Success(:final value)) {
        dates = value;
      } else {
        error = 'Unable to load unavailable dates. Please retry.';
      }
    });
  }

  Future<void> add() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unavailable date'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await ref
        .read(registrationRepositoryProvider)
        .addUnavailableDate(
          widget.assignmentId,
          date.toIso8601String().substring(0, 10),
          text.isEmpty ? null : text,
        );
    if (!mounted) return;
    if (result is Failure<void>) {
      setState(() {
        busy = false;
        error = result.failure.message;
      });
      return;
    }
    await load();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            registrationText('Unavailable Dates', 22, bold: true),
            const SizedBox(height: 18),
            if (busy) const LinearProgressIndicator(),
            for (final date in dates)
              ListTile(
                title: Text('${date['date']}'),
                subtitle: Text('${date['reason'] ?? ''}'),
                trailing: IconButton(
                  tooltip: 'Remove unavailable date',
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          final result = await ref
                              .read(registrationRepositoryProvider)
                              .deleteUnavailableDate(
                                widget.assignmentId,
                                date['unavailableDateId'] as int,
                              );
                          if (!mounted) return;
                          if (result is Failure<void>) {
                            setState(() {
                              busy = false;
                              error = result.failure.message;
                            });
                            return;
                          }
                          await load();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            if (error != null) ...[
              RegistrationNotice(error!, warning: true),
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Retry'),
              ),
            ],
            RegistrationButton(
              'Add Unavailable Date',
              onPressed: busy ? null : add,
            ),
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}
