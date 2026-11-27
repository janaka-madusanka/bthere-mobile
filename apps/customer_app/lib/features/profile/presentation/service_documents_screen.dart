import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../../booking/domain/booking_models.dart';

Map<String, dynamic> scopedDocument(CustomerRequirement r, BookingKey key) => {
  'requirementId': r.field.id,
  'name': r.field.label,
  'fieldType': r.field.type,
  'status': r.status,
  'services': [
    {'serviceTypeId': key.serviceId, 'optionId': key.optionId},
  ],
};

class ServiceDocumentRequirements extends StatelessWidget {
  const ServiceDocumentRequirements({
    super.key,
    required this.requirements,
    required this.bookingKey,
    required this.busy,
    required this.onRefresh,
    required this.onOpen,
    this.error,
    this.eligible = false,
  });
  final List<CustomerRequirement> requirements;
  final BookingKey bookingKey;
  final bool busy, eligible;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<CustomerRequirement> onOpen;

  @override
  Widget build(BuildContext context) {
    final documents = requirements.where((r) => r.field.upload).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE6F7F5), Color(0xFFF2FAFA)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: CustomerColors.action,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      eligible
                          ? 'Documents ready'
                          : 'Documents needed before booking',
                      style: CustomerTypography.section.copyWith(
                        color: const Color(0xFF10143F),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                eligible
                    ? 'Your documents are approved. You can continue with your booking.'
                    : 'Upload your documents here. Once approved, you can book this service.',
                style: CustomerTypography.compact.copyWith(
                  color: CustomerColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (documents.isEmpty && !busy && error == null)
          const Text(
            'No additional documents are required for this service.',
            style: CustomerTypography.body,
          ),
        for (final r in documents)
          Container(
            key: ValueKey('service-document-${r.field.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: CustomerColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: CustomerColors.selection,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        size: 22,
                        color: CustomerColors.action,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.field.label,
                        style: CustomerTypography.card.copyWith(
                          color: const Color(0xFF10143F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: {'REJECTED', 'EXPIRED'}.contains(r.status)
                          ? const Color(0xFFFFEDF0)
                          : r.status == 'PENDING'
                          ? const Color(0xFFFFF4DF)
                          : const Color(0xFFE9F8F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      switch (r.status) {
                        'MISSING' => 'Not submitted',
                        'PENDING' => 'Under review',
                        'APPROVED' => 'Approved',
                        'PROVIDED' => 'Submitted',
                        'REJECTED' => 'Rejected - please resubmit',
                        'EXPIRED' => 'Expired - please resubmit',
                        _ => r.status,
                      },
                      style: CustomerTypography.compactStrong.copyWith(
                        color: {'REJECTED', 'EXPIRED'}.contains(r.status)
                            ? CustomerColors.error
                            : r.status == 'PENDING'
                            ? const Color(0xFF9B6810)
                            : CustomerColors.action,
                      ),
                    ),
                  ),
                ),
                if (r.field.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    r.field.description!,
                    style: CustomerTypography.compact.copyWith(
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ],
                if (r.rejection?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: CustomerColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.rejection!,
                            style: CustomerTypography.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (r.expires != null)
                  Text(
                    'Expiry: ${r.expires}',
                    style: CustomerTypography.compact,
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 18,
                        color: CustomerColors.action,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${r.field.minFiles}-${r.field.maxFiles ?? "many"} files · Up to ${r.field.maxMb} MB each'
                          '${r.field.fileTypes.isEmpty ? "" : "\n${r.field.fileTypes.join(', ')}"}',
                          style: CustomerTypography.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CustomerColors.action,
                    side: const BorderSide(color: Color(0xFFB6E3DF)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: busy ? null : () => onOpen(r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        {'MISSING', 'REJECTED', 'EXPIRED'}.contains(r.status)
                            ? Icons.upload_file_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          {'MISSING', 'REJECTED', 'EXPIRED'}.contains(r.status)
                              ? 'Upload / resubmit'
                              : 'View documents',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (!eligible &&
            requirements.any(
              (r) =>
                  !r.field.upload &&
                  r.blocksBooking &&
                  !{'APPROVED', 'PROVIDED'}.contains(r.status),
            ))
          const Text(
            'Other information is also required. Complete it in the booking form after your documents are ready.',
            style: CustomerTypography.compact,
          ),
        if (error != null)
          Text(
            error!,
            style: CustomerTypography.body.copyWith(
              color: CustomerColors.error,
            ),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: busy ? null : onRefresh,
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  busy ? 'Checking...' : 'Check review status',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
