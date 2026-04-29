import 'package:flutter/material.dart';

class PremiumActionSheet extends StatelessWidget {
  const PremiumActionSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.child,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget? child;

  static Future<bool> showConfirm({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PremiumActionSheet(
        title: title,
        subtitle: subtitle,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A1F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111623),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF0F3FA),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF9EA5B7), fontSize: 14),
            ),
            if (child != null) ...[
              const SizedBox(height: 14),
              child!,
            ],
            const SizedBox(height: 18),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

