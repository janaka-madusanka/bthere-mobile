import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../../discovery/presentation/customer_discovery_style.dart';

import '../../discovery/application/customer_discovery_controller.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../application/customer_booking_controller.dart';

class BookingServiceDropdown extends StatefulWidget {
  const BookingServiceDropdown({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.child,
  });
  final CustomerBookingController controller;
  final ValueChanged<CustomerServiceOption> onChanged;
  final Widget child;
  @override
  State<BookingServiceDropdown> createState() => _BookingServiceDropdownState();
}

class _BookingServiceDropdownState extends State<BookingServiceDropdown> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        widget.controller.discovery.loadOptions(
          widget.controller.key.serviceId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c.discovery,
      builder: (context, _) {
        final state = c.discovery.optionsFor(c.key.serviceId);
        final maxWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
          160.0,
          320.0,
        );
        var menuWidth = 180.0.clamp(160.0, maxWidth);
        for (final option in state.options) {
          final label = TextPainter(
            text: TextSpan(
              text: option.name,
              style: TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 13,
                fontWeight: option.id == c.key.optionId
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          menuWidth = (label.width + 100).clamp(menuWidth, maxWidth);
          label.dispose();
        }
        return PopupMenuButton<int>(
          key: const ValueKey('booking-service-selector'),
          tooltip: 'Change service',
          enabled: !c.busy,
          position: PopupMenuPosition.under,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shadowColor: CustomerColors.text.withValues(alpha: .16),
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
          offset: const Offset(0, 6),
          constraints: BoxConstraints(
            minWidth: menuWidth,
            maxWidth: menuWidth,
            maxHeight: 360,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          itemBuilder: (_) => [
            if (state.stage == DiscoveryStage.ready && state.options.isNotEmpty)
              for (final option in state.options)
                PopupMenuItem<int>(
                  key: ValueKey('booking-service-option-${option.id}'),
                  value: option.id,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  height: 56,
                  child: Semantics(
                    selected: option.id == c.key.optionId,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: option.id == c.key.optionId
                            ? CustomerColors.selection
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CatalogIcon(
                            appearance: const ServiceAppearance(
                              CustomerColors.action,
                              Icons.room_service_outlined,
                            ),
                            url: option.iconUrl,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option.name,
                              style: TextStyle(
                                fontFamily: CustomerTypography.family,
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: option.id == c.key.optionId
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: CustomerColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            option.id == c.key.optionId
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            size: 19,
                            color: CustomerColors.action,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
            else if (state.stage == DiscoveryStage.loading)
              const PopupMenuItem<int>(
                enabled: false,
                child: Text('Loading services…'),
              )
            else
              const PopupMenuItem<int>(
                value: -1,
                child: Text('Reload service options'),
              ),
          ],
          onSelected: (id) {
            if (id == -1) {
              c.discovery.loadOptions(c.key.serviceId, retry: true);
            } else if (id != c.key.optionId && !c.busy && c.alive) {
              final matches = state.options.where((option) => option.id == id);
              if (matches.isNotEmpty) widget.onChanged(matches.first);
            }
          },
          child: widget.child,
        );
      },
    );
  }
}
