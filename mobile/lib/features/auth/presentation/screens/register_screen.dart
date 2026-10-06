import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../infrastructure/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Por favor completa todos los campos requeridos");
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = "Las contraseñas no coinciden");
      return;
    }

    if (!_acceptTerms) {
      setState(() => _errorMessage = "Debes aceptar los términos y condiciones de uso");
      return;
    }

    try {
      final authService = context.read<AuthService>();
      await authService.signUpWithEmail(email, password);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n?.translate('auth.register') ?? 'Crear cuenta'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentRose.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentRose.withOpacity(0.4)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: i18n?.translate('auth.full_name') ?? 'Nombre completo',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: i18n?.translate('auth.email') ?? 'Correo electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: i18n?.translate('auth.password') ?? 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: i18n?.translate('auth.confirm_password') ?? 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.lock_reset),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                i18n?.translate('auth.accept_terms') ?? 'Acepto los términos y condiciones',
                style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary),
              ),
              value: _acceptTerms,
              onChanged: (val) => setState(() => _acceptTerms = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: AppSpacing.lg),

            ElevatedButton(
              onPressed: authService.isLoading ? null : _submit,
              child: authService.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(i18n?.translate('auth.register') ?? 'Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
