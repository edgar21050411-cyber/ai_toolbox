abstract class AppError implements Exception {
  final String message;
  final String? technicalDetails;
  final String? code;

  const AppError({
    required this.message,
    this.technicalDetails,
    this.code,
  });

  @override
  String toString() => '$runtimeType: $message${code != null ? ' ($code)' : ''}';
}

class NetworkError extends AppError {
  const NetworkError({
    super.message = 'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
    super.technicalDetails,
    super.code = 'NETWORK_ERROR',
  });
}

class AuthenticationError extends AppError {
  const AuthenticationError({
    super.message = 'Error de autenticación. Por favor inicia sesión nuevamente.',
    super.technicalDetails,
    super.code = 'AUTH_ERROR',
  });
}

class InsufficientCreditsError extends AppError {
  final int requiredCredits;
  final int currentBalance;

  const InsufficientCreditsError({
    required this.requiredCredits,
    required this.currentBalance,
    super.message = 'No tienes suficientes créditos para completar esta acción.',
    super.technicalDetails,
    super.code = 'INSUFFICIENT_CREDITS',
  });
}

class ToolUnavailableError extends AppError {
  final String toolSlug;

  const ToolUnavailableError({
    required this.toolSlug,
    super.message = 'Esta herramienta no está disponible temporalmente.',
    super.technicalDetails,
    super.code = 'TOOL_UNAVAILABLE',
  });
}

class AIProviderError extends AppError {
  final String provider;

  const AIProviderError({
    required this.provider,
    super.message = 'El motor de IA experimentó un error temporal. Tus créditos están protegidos.',
    super.technicalDetails,
    super.code = 'AI_PROVIDER_ERROR',
  });
}

class StorageError extends AppError {
  const StorageError({
    super.message = 'No se pudo cargar o guardar el archivo seleccionado.',
    super.technicalDetails,
    super.code = 'STORAGE_ERROR',
  });
}

class ValidationError extends AppError {
  const ValidationError({
    required super.message,
    super.technicalDetails,
    super.code = 'VALIDATION_ERROR',
  });
}
