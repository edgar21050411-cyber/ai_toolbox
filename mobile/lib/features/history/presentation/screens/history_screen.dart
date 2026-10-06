import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../data/history_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryRepository>().fetchHistory();
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.accentGreen;
      case 'processing':
        return AppColors.accentAmber;
      case 'failed':
        return AppColors.accentRose;
      default:
        return AppColors.darkTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);
    final historyRepo = context.watch<HistoryRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n?.translate('history.title') ?? 'Historial de Creaciones', style: AppTypography.heading2),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: historyRepo.isLoading
          ? const Center(child: CircularProgressIndicator())
          : historyRepo.generations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: AppColors.darkTextSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        i18n?.translate('history.empty') ?? 'Aún no tienes generaciones registradas.',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: historyRepo.generations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final gen = historyRepo.generations[index];
                    final statusColor = _getStatusColor(gen.status);

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  gen.toolId ?? 'Herramienta de IA',
                                  style: AppTypography.heading2.copyWith(fontSize: 15, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${gen.provider ?? "AI"} (${gen.model ?? "default"}) • ${gen.creditsUsed} créditos',
                                  style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            i18n?.translate('history.status.${gen.status}') ?? gen.status,
                            style: AppTypography.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
