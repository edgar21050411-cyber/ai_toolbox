import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CreditBadge extends StatelessWidget {
  final int balance;
  final VoidCallback onTap;

  const CreditBadge({
    super.key,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: AppTheme.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              '$balance créditos',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.add_circle, color: AppTheme.primary, size: 16),
          ],
        ),
      ),
    );
  }
}
