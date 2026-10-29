import 'package:flutter/material.dart';

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
        return PopupMenuButton<int>(
          key: const ValueKey('booking-service-selector'),
          tooltip: 'Change service',
          enabled: !c.busy,
          position: PopupMenuPosition.under,
          constraints: const BoxConstraints(
            minWidth: 220,
            maxWidth: 320,
            maxHeight: 360,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          itemBuilder: (_) => [
            if (state.stage == DiscoveryStage.ready && state.options.isNotEmpty)
              for (final option in state.options)
                CheckedPopupMenuItem<int>(
                  key: ValueKey('booking-service-option-${option.id}'),
                  value: option.id,
                  checked: option.id == c.key.optionId,
                  child: Text(option.name),
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
