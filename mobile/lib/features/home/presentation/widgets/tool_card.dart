import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tools/domain/tool_entity.dart';

class ToolCard extends StatelessWidget {
  final ToolEntity tool;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.tool,
    required this.onTap,
  });

  IconData _mapIcon(String iconName) {
    switch (iconName) {
      case 'layers_clear':
        return Icons.layers_clear;
      case 'auto_fix_high':
        return Icons.auto_fix_high;
      case 'wallpaper':
        return Icons.wallpaper;
      case 'campaign':
        return Icons.campaign;
      case 'share':
        return Icons.share;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'edit_note':
        return Icons.edit_note;
      case 'translate':
        return Icons.translate;
      case 'summarize':
        return Icons.summarize;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final title = tool.getLocalizedName(lang);
    final desc = tool.getLocalizedDescription(lang);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_mapIcon(tool.icon), color: AppTheme.primary, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: AppTheme.accentAmber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        '${tool.creditCost}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryDark,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
