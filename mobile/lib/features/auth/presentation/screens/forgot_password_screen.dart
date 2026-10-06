import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/i18n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendRecovery() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _message = "Por favor ingresa tu correo electrónico";
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      setState(() {
        _isSuccess = true;
        _message = "Se ha enviado un correo con instrucciones para restablecer tu contraseña.";
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n?.translate('auth.recover_password') ?? 'Recuperar contraseña'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ingresa tu correo para recibir un enlace de recuperación:',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (_isSuccess ? AppColors.accentGreen : AppColors.accentRose).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isSuccess ? AppColors.accentGreen : AppColors.accentRose).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _isSuccess ? AppColors.accentGreen : Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: i18n?.translate('auth.email') ?? 'Correo electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            ElevatedButton(
              onPressed: _isLoading ? null : _sendRecovery,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(i18n?.translate('auth.send_recovery_email') ?? 'Enviar enlace'),
            ),
          ],
        ),
      ),
    );
  }
}
