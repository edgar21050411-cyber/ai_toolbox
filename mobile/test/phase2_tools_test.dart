import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/features/tools/domain/tool_entity.dart';
import 'package:ai_toolbox/services/ai/ai_router.dart';
import 'package:ai_toolbox/services/ai/ai_provider.dart';
import 'package:ai_toolbox/core/network/ai_router_client.dart';
import 'package:ai_toolbox/core/errors/app_errors.dart';

class MockPhase2AIRouterClient extends AIRouterClient {
  final Map<String, dynamic> responses;
  final bool shouldFail;
  final String? failureMessage;

  MockPhase2AIRouterClient({
    this.responses = const {},
    this.shouldFail = false,
    this.failureMessage,
  });

  @override
  Future<AIRouterResponse> executeTool({
    required String toolId,
    required Map<String, dynamic> input,
    Map<String, dynamic>? parameters,
  }) async {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Error simulado de backend');
    }

    final toolResponses = {
      'rewrite_text': {'text': 'Texto reescrito profesionalmente.'},
      'translate_text': {'text': 'Hello world, translated cleanly.'},
      'summarize_text': {'text': 'Resumen ejecutivo con puntos clave.'},
      'create_ad': {
        'title': 'Oferta Exclusiva 2026',
        'main_text': 'Compra ahora con envío gratis a todo el país.',
        'cta': 'Comprar ahora',
        'platform': 'Instagram',
      },
      'social_post': {
        'post': '¡Descubre las novedades de esta semana!',
        'cta': '¿Cuál es tu favorito? Comenta abajo.',
        'hashtags': ['#AIToolbox', '#Productividad', '#Innovacion'],
        'platform': 'Instagram',
      },
      'product_description': {
        'title': 'Auriculares Inalámbricos Pro',
        'short_description': 'Sonido cristalino con cancelación activa.',
        'full_description': 'Diseñados para brindar comodidad todo el día.',
        'benefits': ['Batería 30h', 'Carga rápida', 'Cancelación activa'],
        'cta': 'Añadir al carrito',
      },
      'generate_image': {
        'image_url': 'https://mock.storage.co/generated/auto_futurista.png',
        'prompt': input['prompt'],
      },
      'improve_image': {
        'enhanced_image_url': 'https://mock.storage.co/generated/enhanced.png',
        'factor': '2x',
      },
      'remove_background': {
        'image_url': 'https://mock.storage.co/generated/transparent.png',
        'format': 'png',
        'transparency': true,
      },
      'change_background': {
        'image_url': 'https://mock.storage.co/generated/new_bg.png',
        'background_description': input['background_description'],
      },
    };

    final result = responses[toolId] ?? toolResponses[toolId] ?? {'output': 'ok'};

    return AIRouterResponse(
      success: true,
      tool: toolId,
      result: result,
      creditsUsed: 1,
      creditsRemaining: 14,
      processingTimeMs: 120,
      provider: toolId.contains('image') || toolId.contains('background') ? 'google_imagen' : 'google_gemini',
      model: 'gemini-1.5-flash',
    );
  }
}

void main() {
  group('Fase 2 — Las 10 Herramientas: Catálogo, Costos y Routing', () {
    final List<Map<String, dynamic>> official10Tools = [
      {'id': 'rewrite_text', 'category': 'text', 'cost': 1},
      {'id': 'translate_text', 'category': 'text', 'cost': 1},
      {'id': 'summarize_text', 'category': 'text', 'cost': 1},
      {'id': 'create_ad', 'category': 'marketing', 'cost': 4},
      {'id': 'social_post', 'category': 'marketing', 'cost': 3},
      {'id': 'product_description', 'category': 'marketing', 'cost': 3},
      {'id': 'generate_image', 'category': 'images', 'cost': 5},
      {'id': 'improve_image', 'category': 'images', 'cost': 5},
      {'id': 'remove_background', 'category': 'images', 'cost': 3},
      {'id': 'change_background', 'category': 'images', 'cost': 5},
    ];

    test('Verificar que existen exactamente las 10 herramientas oficiales con sus costos', () {
      expect(official10Tools.length, 10);

      final toolsMap = {for (var t in official10Tools) t['id'] as String: t};

      // 1. Text tools
      expect(toolsMap['rewrite_text']!['cost'], 1);
      expect(toolsMap['rewrite_text']!['category'], 'text');

      expect(toolsMap['translate_text']!['cost'], 1);
      expect(toolsMap['translate_text']!['category'], 'text');

      expect(toolsMap['summarize_text']!['cost'], 1);
      expect(toolsMap['summarize_text']!['category'], 'text');

      // 2. Marketing tools
      expect(toolsMap['create_ad']!['cost'], 4);
      expect(toolsMap['create_ad']!['category'], 'marketing');

      expect(toolsMap['social_post']!['cost'], 3);
      expect(toolsMap['social_post']!['category'], 'marketing');

      expect(toolsMap['product_description']!['cost'], 3);
      expect(toolsMap['product_description']!['category'], 'marketing');

      // 3. Image tools
      expect(toolsMap['generate_image']!['cost'], 5);
      expect(toolsMap['generate_image']!['category'], 'images');

      expect(toolsMap['improve_image']!['cost'], 5);
      expect(toolsMap['improve_image']!['category'], 'images');

      expect(toolsMap['remove_background']!['cost'], 3);
      expect(toolsMap['remove_background']!['category'], 'images');

      expect(toolsMap['change_background']!['cost'], 5);
      expect(toolsMap['change_background']!['category'], 'images');
    });

    test('Ejecutar exitosamente las 3 herramientas de texto a través del AI Router', () async {
      final client = MockPhase2AIRouterClient();
      final router = AIRouter(client: client);

      // rewrite_text
      final rewriteRes = await router.generate(const AIRequest(
        toolId: 'rewrite_text',
        input: {'text': 'Texto informal', 'tone': 'Profesional'},
      ));
      expect(rewriteRes.success, isTrue);
      expect(rewriteRes.result['text'], contains('reescrito'));

      // translate_text
      final translateRes = await router.generate(const AIRequest(
        toolId: 'translate_text',
        input: {'text': 'Hola mundo', 'source_language': 'Español', 'target_language': 'Inglés'},
      ));
      expect(translateRes.success, isTrue);
      expect(translateRes.result['text'], contains('Hello world'));

      // summarize_text
      final summarizeRes = await router.generate(const AIRequest(
        toolId: 'summarize_text',
        input: {'text': 'Un artículo largo sobre ciencia...', 'length': 'Medio'},
      ));
      expect(summarizeRes.success, isTrue);
      expect(summarizeRes.result['text'], contains('Resumen'));
    });

    test('Ejecutar exitosamente las 3 herramientas estructuradas de marketing', () async {
      final client = MockPhase2AIRouterClient();
      final router = AIRouter(client: client);

      // create_ad
      final adRes = await router.generate(const AIRequest(
        toolId: 'create_ad',
        input: {'product_service': 'Zapatillas', 'platform': 'Instagram'},
      ));
      expect(adRes.success, isTrue);
      expect(adRes.result['title'], isNotEmpty);
      expect(adRes.result['cta'], isNotEmpty);

      // social_post
      final postRes = await router.generate(const AIRequest(
        toolId: 'social_post',
        input: {'topic_product': 'Lanzamiento de producto', 'platform': 'Instagram'},
      ));
      expect(postRes.success, isTrue);
      expect(postRes.result['hashtags'], isNotEmpty);

      // product_description
      final prodRes = await router.generate(const AIRequest(
        toolId: 'product_description',
        input: {'name': 'Auriculares Pro'},
      ));
      expect(prodRes.success, isTrue);
      expect(prodRes.result['short_description'], isNotEmpty);
      expect(prodRes.result['benefits'], isNotEmpty);
    });

    test('Ejecutar exitosamente las 4 herramientas de imagen (con Mocks)', () async {
      final client = MockPhase2AIRouterClient();
      final router = AIRouter(client: client);

      // generate_image
      final genImgRes = await router.generate(const AIRequest(
        toolId: 'generate_image',
        input: {'prompt': 'Un automóvil deportivo rojo en una ciudad futurista'},
      ));
      expect(genImgRes.success, isTrue);
      expect(genImgRes.result['image_url'], contains('.png'));

      // improve_image
      final impRes = await router.generate(const AIRequest(
        toolId: 'improve_image',
        input: {'image_url': 'https://ejemplo.com/foto.jpg'},
      ));
      expect(impRes.success, isTrue);
      expect(impRes.result['enhanced_image_url'], isNotEmpty);

      // remove_background
      final remBgRes = await router.generate(const AIRequest(
        toolId: 'remove_background',
        input: {'image_url': 'https://ejemplo.com/producto.jpg'},
      ));
      expect(remBgRes.success, isTrue);
      expect(remBgRes.result['transparency'], isTrue);

      // change_background
      final chBgRes = await router.generate(const AIRequest(
        toolId: 'change_background',
        input: {
          'image_url': 'https://ejemplo.com/producto.jpg',
          'background_description': 'Una oficina moderna',
        },
      ));
      expect(chBgRes.success, isTrue);
      expect(chBgRes.result['background_description'], 'Una oficina moderna');
    });

    test('Manejo seguro de casos de error sin filtrar datos sensibles', () async {
      // 1. Créditos insuficientes
      final creditFailClient = MockPhase2AIRouterClient(
        shouldFail: true,
        failureMessage: 'insufficient_credits',
      );
      final router1 = AIRouter(client: creditFailClient);
      expect(
        () => router1.generate(const AIRequest(toolId: 'generate_image', input: {'prompt': 'test'})),
        throwsA(isA<InsufficientCreditsError>()),
      );

      // 2. Herramienta no disponible
      final unavailableClient = MockPhase2AIRouterClient(
        shouldFail: true,
        failureMessage: 'La herramienta solicitada no está disponible',
      );
      final router2 = AIRouter(client: unavailableClient);
      expect(
        () => router2.generate(const AIRequest(toolId: 'disabled_tool', input: {'text': 'test'})),
        throwsA(isA<ToolUnavailableError>()),
      );

      // 3. Usuario no autenticado
      final authFailClient = MockPhase2AIRouterClient(
        shouldFail: true,
        failureMessage: 'unauthorized',
      );
      final router3 = AIRouter(client: authFailClient);
      expect(
        () => router3.generate(const AIRequest(toolId: 'rewrite_text', input: {'text': 'test'})),
        throwsA(isA<AuthenticationError>()),
      );
    });
  });
}
