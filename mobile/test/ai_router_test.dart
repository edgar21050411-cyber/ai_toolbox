import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/services/ai/ai_router.dart';
import 'package:ai_toolbox/services/ai/ai_provider.dart';
import 'package:ai_toolbox/core/network/ai_router_client.dart';
import 'package:ai_toolbox/core/errors/app_errors.dart';

class MockAIRouterClient extends AIRouterClient {
  final bool shouldFail;
  final String? errorMessage;

  MockAIRouterClient({this.shouldFail = false, this.errorMessage});

  @override
  Future<AIRouterResponse> executeTool({
    required String toolId,
    required Map<String, dynamic> input,
    Map<String, dynamic>? parameters,
  }) async {
    if (shouldFail) {
      throw Exception(errorMessage ?? 'Network failure');
    }

    return AIRouterResponse(
      success: true,
      tool: toolId,
      result: {'output': 'test_success_output'},
      creditsUsed: 1,
      creditsRemaining: 14,
      processingTimeMs: 150,
      provider: 'google_gemini',
      model: 'gemini-1.5-flash',
    );
  }
}

void main() {
  group('AIRouter Client Tests', () {
    test('AIRouter delegates successfully to AIRouterClient', () async {
      final mockClient = MockAIRouterClient();
      final router = AIRouter(client: mockClient);

      const req = AIRequest(
        toolId: 'rewrite_text',
        input: {'text': 'Hola mundo'},
      );

      final response = await router.generate(req);

      expect(response.success, isTrue);
      expect(response.toolId, 'rewrite_text');
      expect(response.provider, 'google_gemini');
      expect(response.result['output'], 'test_success_output');
    });

    test('AIRouter maps insufficient credits error properly', () async {
      final mockClient = MockAIRouterClient(
        shouldFail: true,
        errorMessage: 'insufficient credits',
      );
      final router = AIRouter(client: mockClient);

      const req = AIRequest(
        toolId: 'create_campaign',
        input: {'text': 'Tienda de zapatos'},
      );

      expect(
        () => router.generate(req),
        throwsA(isA<InsufficientCreditsError>()),
      );
    });

    test('AIRouter maps unavailable tool error properly', () async {
      final mockClient = MockAIRouterClient(
        shouldFail: true,
        errorMessage: 'herramienta no disponible',
      );
      final router = AIRouter(client: mockClient);

      const req = AIRequest(
        toolId: 'disabled_tool',
        input: {'text': 'test'},
      );

      expect(
        () => router.generate(req),
        throwsA(isA<ToolUnavailableError>()),
      );
    });
  });
}
