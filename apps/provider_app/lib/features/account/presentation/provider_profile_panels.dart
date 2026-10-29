part of 'provider_account_screen.dart';

class _PersonalPanel extends ConsumerWidget {
  const _PersonalPanel({
    required this.name,
    this.email,
    this.phone,
    this.profile,
    this.supplement,
  });
  final String name;
  final String? email, phone;
  final Map<String, dynamic>? profile;
  final ProfileSupplement? supplement;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.tryParse('${profile?['dateOfBirth']}');
    final today = ref.watch(clockProvider)();
    final age = date == null
        ? null
        : today.year -
              date.year -
              ((today.month < date.month ||
                      (today.month == date.month && today.day < date.day))
                  ? 1
                  : 0);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final birth = date == null
        ? '\u2014'
        : '${date.year} ${months[date.month - 1]} ${date.day} \u00B7 $age years';
    final location = [
      supplement?.city,
      supplement?.country,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final left = [
      _PersonalField('imgIcon', name, label: 'Name'),
      _PersonalField(
        'imgMail',
        email?.trim().isNotEmpty == true ? email! : '\u2014',
        label: 'Email',
      ),
      _PersonalField('imgIcon1', birth, label: 'Date of birth'),
    ];
    final right = [
      _PersonalField(
        'imgPhone',
        phone?.trim().isNotEmpty == true ? phone! : '\u2014',
        label: 'Phone',
      ),
      _PersonalField(
        'imgMapPin',
        location.isEmpty ? '\u2014' : location,
        label: 'Location',
      ),
      _PersonalField(
        'imgVenus',
        profile == null ? '\u2014' : _readable(profile!['gender']),
        label: 'Gender',
      ),
    ];
    return _Panel(
      child: MediaQuery.textScalerOf(context).scale(12) > 15.6
          ? Column(children: [...left, ...right])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: left)),
                const SizedBox(width: 12),
                Expanded(child: Column(children: right)),
              ],
            ),
    );
  }
}

class _PersonalField extends StatelessWidget {
  const _PersonalField(this.asset, this.value, {required this.label});
  final String asset, value, label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      constraints: const BoxConstraints(minHeight: 32),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3), width: .5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: _asset(asset, 10)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10, color: Color(0xFF424242)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PayoutPanel extends StatelessWidget {
  const _PayoutPanel({required this.value});
  final ProfilePayout? value;
  @override
  Widget build(BuildContext context) {
    final left = Column(
      children: [
        _PayoutField('imgCreditCard', 'Payment Method', value?.method),
        _PayoutField('imgCreditCard', 'Account Number', value?.accountNumber),
      ],
    );
    final right = Column(
      children: [
        _PayoutField('imgLandmark', 'Bank Name', value?.bankName),
        _PayoutField('imgIcon4', 'Account Holder Name', value?.accountHolder),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: MediaQuery.textScalerOf(context).scale(12) > 15.6
              ? Column(children: [left, right])
              : Row(
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 12),
                    Expanded(child: right),
                  ],
                ),
        ),
        if (value == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Payment details are not available yet.',
              style: TextStyle(fontSize: 9, color: _muted),
            ),
          ),
      ],
    );
  }
}

class _PayoutField extends StatelessWidget {
  const _PayoutField(this.asset, this.label, this.value);
  final String asset, label;
  final String? value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 19),
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3), width: .5)),
    ),
    child: Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFFF3F8FB),
            shape: BoxShape.circle,
          ),
          child: Center(child: _asset(asset, 7)),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 8, color: Color(0xFF566186)),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value?.isNotEmpty == true ? value! : '\u2014',
            style: const TextStyle(fontSize: 8, color: _muted),
          ),
        ),
      ],
    ),
  );
}

class _DocumentsPanel extends ConsumerWidget {
  const _DocumentsPanel({required this.onEdit});
  final Future<void> Function(ProfileDocumentRequirement)? onEdit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(profileDocumentsProvider),
        requirements = ref.watch(profileDocumentRequirementsProvider);
    final docsResult = documents.asData?.value,
        reqResult = requirements.asData?.value;
    if (documents.isLoading || requirements.isLoading) {
      return const LinearProgressIndicator();
    }
    if (docsResult is! Success<List<ProviderDocument>>) {
      return _Retry(
        label: 'Unable to load documents.',
        onRetry: () => ref.invalidate(profileDocumentsProvider),
      );
    }
    final reqs = reqResult is Success<List<ProfileDocumentRequirement>>
        ? reqResult.value
        : <ProfileDocumentRequirement>[];
    final docs = docsResult.value;
    final typeIds = {
      ...reqs.map((r) => r.requirement.id),
      ...docs.map((d) => d.typeId),
    };
    final now = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reqResult is! Success<List<ProfileDocumentRequirement>>)
          _Retry(
            label: 'Unable to load document requirements.',
            onRetry: () => ref.invalidate(profileDocumentRequirementsProvider),
          ),
        if (typeIds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'No documents uploaded yet.',
              style: TextStyle(color: _muted),
            ),
          ),
        for (final type in typeIds)
          Builder(
            builder: (context) {
              final entry = reqs
                  .where((r) => r.requirement.id == type)
                  .firstOrNull;
              final matches = docs.where((d) => d.typeId == type).toList();
              final doc =
                  matches
                      .where((d) => d.status(now) == 'Approved')
                      .firstOrNull ??
                  matches.firstOrNull;
              final status = doc?.status(now) ?? 'Missing';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _Panel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry?.requirement.name ??
                                    (doc!.typeName.isNotEmpty
                                        ? doc.typeName
                                        : doc.name),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry?.requirement.required == true
                                    ? 'Required for registration'
                                    : 'Supporting document',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _muted,
                                ),
                              ),
                              if (doc?.rejectionReason?.isNotEmpty == true)
                                Text(
                                  doc!.rejectionReason!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (doc != null)
                          _DocumentThumbnail(document: doc)
                        else
                          Semantics(
                            label: 'Upload ${entry?.requirement.name}',
                            button: true,
                            child: InkWell(
                              onTap: entry == null || onEdit == null
                                  ? null
                                  : () => onEdit!(entry),
                              child: SizedBox(
                                width: 30,
                                height: 32,
                                child: Center(
                                  child: Container(
                                    width: 21,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFBEC9E9),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: _asset('imgAddDocument', 14),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          width: .5,
                          height: 23,
                          color: const Color(0xFFE8ECF3),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 66,
                          child: Column(
                            children: [
                              _DocumentStatus(status),
                              const SizedBox(height: 4),
                              Text(
                                doc?.expiryDate != null
                                    ? _shortDate(doc!.expiryDate!)
                                    : doc?.createdAt != null
                                    ? _shortDate(doc!.createdAt!)
                                    : 'Not uploaded',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

String _shortDate(DateTime date) =>
    '${date.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

class _DocumentStatus extends StatelessWidget {
  const _DocumentStatus(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final approved = status == 'Approved',
        pending = status == 'Pending approval';
    final color = approved
        ? const Color(0xFF08B557)
        : pending
        ? const Color(0xFFFFA500)
        : const Color(0xFFE53935);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: approved
            ? const Color(0xFFEBFBF3)
            : pending
            ? const Color(0xFFFFF8E8)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _asset(
            approved
                ? 'imgCheck'
                : pending
                ? 'imgIcon3'
                : 'imgIcon2',
            7,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              approved
                  ? 'Verified'
                  : pending
                  ? 'Reviewing'
                  : status,
              style: TextStyle(fontSize: 8, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentThumbnail extends ConsumerWidget {
  const _DocumentThumbnail({required this.document});
  final ProviderDocument document;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = RegExp(
      r'\.(png|jpe?g|webp)$',
      caseSensitive: false,
    ).hasMatch(document.key);
    final result = image && document.key.isNotEmpty
        ? ref.watch(profileDocumentUrlProvider(document.key)).asData?.value
        : null;
    final uri = result is Success<Uri> ? result.value : null;
    final thumbnail = uri == null
        ? _asset('imgFileText', 20)
        : Image.network(
            uri.toString(),
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => _asset('imgFileText', 20),
          );
    return Semantics(
      label: 'View ${document.typeName}',
      button: true,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              document.name.isNotEmpty ? document.name : document.typeName,
            ),
            content: uri != null
                ? InteractiveViewer(
                    child: Image.network(
                      uri.toString(),
                      errorBuilder: (_, e, s) =>
                          const Text('Unable to load preview.'),
                    ),
                  )
                : Text(
                    'Document number: ${document.number.isEmpty ? '\u2014' : document.number}\nVerification: ${_readable(document.verificationStatus)}',
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(width: 25, height: 23, child: thumbnail),
        ),
      ),
    );
  }
}
