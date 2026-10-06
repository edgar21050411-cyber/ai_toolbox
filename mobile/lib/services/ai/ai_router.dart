import 'ai_provider.dart';
import '../../core/network/ai_router_client.dart';
import '../../core/errors/app_errors.dart';
import '../logging/logger_service.dart';

class AIRouter {
  final AIRouterClient _client;
  final LoggerService _logger = LoggerService();

  AIRouter({AIRouterClient? client}) : _client = client ?? AIRouterClient();

    /// Enruta la solicitud hacia la Edge Function del backend de forma segura.
  /// La app cliente NUNCA interactúa directamente con OpenAI o Gemini.
  Future<AIResponse> generate(AIRequest request) async {
    _logger.info(
      'AIRouter delegating tool execution to Supabase Edge Function',
      tool: request.toolId,
    );

    try {
      final response = await _client.executeTool(
        toolId: request.toolId,
        input: request.input,
        parameters: request.parameters,
      );

      return AIResponse(
        success: response.success,
        toolId: response.tool,
        result: response.result,
        provider: response.provider,
        model: response.model,
        processingTimeMs: response.processingTimeMs,
      );
    } catch (e, stack) {
      _logger.error(
        'AI Router request failed in backend',
        tool: request.toolId,
        error: e,
        stackTrace: stack,
      );

      final msg = e.toString().toLowerCase();
      if (msg.contains('insufficient') || msg.contains('créditos') || msg.contains('creditos')) {
        throw const InsufficientCreditsError(requiredCredits: 0, currentBalance: 0);
      } else if (msg.contains('no disponible') || msg.contains('no está disponible') || msg.contains('no esta disponible') || msg.contains('unavailable')) {
        throw ToolUnavailableError(toolSlug: request.toolId);
      } else if (msg.contains('unauthorized') || msg.contains('autorización') || msg.contains('autorizacion')) {
        throw const AuthenticationError();
      }

      throw AIProviderError(
        provider: 'backend_router',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}
