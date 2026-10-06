import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/features/auth/domain/user_profile.dart';
import 'package:ai_toolbox/features/tools/domain/tool_entity.dart';
import 'package:ai_toolbox/features/history/domain/generation.dart';
import 'package:ai_toolbox/features/projects/domain/project.dart';

void main() {
  group('Domain Models Unit Tests', () {
    test('UserProfile handles credit balance and plans', () {
      final profile = UserProfile(
        id: 'u-1',
        email: 'user@test.com',
        displayName: 'Test User',
        language: 'es',
        plan: 'free',
        creditBalance: 15,
        createdAt: DateTime.now(),
      );

      expect(profile.creditBalance, 15);
      expect(profile.plan, 'free');

      final updated = profile.copyWith(creditBalance: 10, plan: 'pro');
      expect(updated.creditBalance, 10);
      expect(updated.plan, 'pro');
    });

    test('ToolEntity parses localized fields and category accurately', () {
      final tool = ToolEntity.fromMap({
        'id': 'create_ad',
        'slug': 'crear-anuncio',
        'name': {'es': 'Crear anuncio', 'en': 'Create Ad'},
        'description': {'es': 'Crea copias persuasivas', 'en': 'Create persuasive copy'},
        'category': 'marketing',
        'icon': 'campaign',
        'enabled': true,
        'beta': false,
        'minimum_plan': 'free',
        'credit_cost': 5,
        'sort_order': 4,
      });

      expect(tool.id, 'create_ad');
      expect(tool.slug, 'crear-anuncio');
      expect(tool.getLocalizedName('es'), 'Crear anuncio');
      expect(tool.getLocalizedName('en'), 'Create Ad');
      expect(tool.creditCost, 5);
      expect(tool.category, 'marketing');
    });

    test('Generation parses status correctly', () {
      final gen = Generation.fromMap({
        'id': 'gen-123',
        'user_id': 'u-1',
        'tool_id': 'remove_bg',
        'provider': 'google_vision_segmentation',
        'model': 'segmentation-v2',
        'credits_used': 3,
        'estimated_api_cost': 0.005,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(gen.id, 'gen-123');
      expect(gen.status, 'completed');
      expect(gen.creditsUsed, 3);
      expect(gen.estimatedApiCost, 0.005);
    });

    test('Project model parses attributes accurately', () {
      final proj = Project.fromMap({
        'id': 'proj-1',
        'user_id': 'u-1',
        'name': 'Tienda de Ropa',
        'description': 'Campaña de verano',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(proj.name, 'Tienda de Ropa');
      expect(proj.description, 'Campaña de verano');
    });
  });
}
