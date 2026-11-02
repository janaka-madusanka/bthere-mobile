import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../bookings/presentation/booking_scaffold.dart';

/// The supplied contract has no messaging endpoints. Never invent conversations.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int selected = 0;
  String query = '';
  @override
  Widget build(BuildContext context) => BookingScaffold(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 17),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              Tooltip(
                message: 'Messaging is not available yet',
                child: Container(
                  width: 30,
                  height: 30,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SvgPicture.asset(
                    'assets/messages/imgSquarePen.svg',
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => query = value),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search conversations',
              hintStyle: const TextStyle(color: bookingMuted, fontSize: 12),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(11),
                child: SvgPicture.asset(
                  'assets/messages/imgSearch.svg',
                  width: 15,
                  height: 15,
                ),
              ),
              prefixIconConstraints: const BoxConstraints.tightFor(
                width: 36,
                height: 37,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F8),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 15),
          BookingFilters(
            labels: const ['All', 'Unread', 'Clients', 'Requests'],
            selected: selected,
            onSelect: (value) => setState(() => selected = value),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 40,
                      color: bookingMuted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      query.isEmpty
                          ? 'No conversations yet'
                          : 'No conversations found',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: bookingInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your conversations will appear here.',
                      style: TextStyle(color: bookingMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
