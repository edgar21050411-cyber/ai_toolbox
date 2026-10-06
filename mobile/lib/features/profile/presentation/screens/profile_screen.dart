import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../auth/infrastructure/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);
    final authService = context.watch<AuthService>();
    final profile = authService.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n?.translate('nav.profile') ?? 'Perfil', style: AppTypography.heading2),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // User Avatar Card
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.person, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    profile?.displayName ?? 'Usuario',
                    style: AppTypography.heading1.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.email ?? '',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PLAN: ${(profile?.plan ?? "free").toUpperCase()}',
                      style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Opciones de configuración
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bolt, color: AppColors.accentAmber),
                    title: Text(i18n?.translate('credits.balance') ?? 'Créditos'),
                    trailing: Text(
                      '${profile?.creditBalance ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accentAmber),
                    ),
                  ),
                  const Divider(color: AppColors.darkBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.language, color: AppColors.primary),
                    title: const Text('Idioma / Language'),
                    trailing: Text(
                      profile?.language == 'en' ? 'English' : 'Español',
                      style: const TextStyle(color: AppColors.darkTextSecondary),
                    ),
                  ),
                  const Divider(color: AppColors.darkBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.dark_mode, color: AppColors.secondary),
                    title: const Text('Tema'),
                    trailing: const Text('Oscuro (Default)', style: TextStyle(color: AppColors.darkTextSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Logout Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRose.withOpacity(0.15),
                foregroundColor: AppColors.accentRose,
                side: const BorderSide(color: AppColors.accentRose),
              ),
              onPressed: () => authService.signOut(),
              icon: const Icon(Icons.logout),
              label: Text(i18n?.translate('auth.logout') ?? 'Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
