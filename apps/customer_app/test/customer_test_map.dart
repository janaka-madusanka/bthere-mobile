import 'package:customer_app/features/booking/presentation/customer_booking_map.dart';
import 'package:flutter/material.dart';

export 'package:customer_app/features/booking/presentation/customer_booking_map.dart';

/// Native map substitute: selection and camera state remain observable.
class CustomerTestMap extends StatelessWidget {
  const CustomerTestMap(this.state, {super.key});
  final CustomerMapState state;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: state.onSelect == null
        ? null
        : () => state.onSelect!(state.camera.target),
    child: const SizedBox.expand(child: ColoredBox(color: Color(0xFFE9F6F4))),
  );
}
