import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

/// Profile setup inside the provider navigation shell.
class ProviderProfilePage extends StatelessWidget {
  const ProviderProfilePage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).brightness == Brightness.dark
        ? BThereTheme.dark()
        : BThereTheme.authentication(),
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF009B9D), Color(0xFF006568)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(0xFFDCF7F3),
                            foregroundColor: Color(0xFF008B8E),
                            radius: 22,
                            child: Icon(Icons.person_outline_rounded),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your provider profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(
                          bounds.maxWidth < 360 ? 16 : 24,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
