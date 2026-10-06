import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/features/tools/domain/tool_entity.dart';
import 'package:ai_toolbox/features/auth/domain/user_profile.dart';
import 'package:ai_toolbox/features/credits/domain/credit_transaction.dart';

void main() {
  group('AI Toolbox - Foundation Domain Models Tests', () {
    test('ToolEntity parses correctly and respects localization', () {
      final map = {
        'id': 'remove_bg',
        'name': {'es': 'Quitar fondo', 'en': 'Remove Background'},
        'description': {'es': 'Elimina el fondo', 'en': 'Remove background'},
        'category': 'improve',
        'icon': 'layers_clear',
        'enabled': true,
        'beta': false,
        'minimum_plan': 'free',
        'credit_cost': 3,
        'sort_order': 1,
      };

      final tool = ToolEntity.fromMap(map);

      expect(tool.id, 'remove_bg');
      expect(tool.getLocalizedName('es'), 'Quitar fondo');
      expect(tool.getLocalizedName('en'), 'Remove Background');
      expect(tool.creditCost, 3);
      expect(tool.enabled, true);
    });

    test('UserProfile updates credit balance accurately', () {
      final profile = UserProfile(
        id: 'user-uuid-123',
        email: 'test@aitoolbox.com',
        displayName: 'Test User',
        language: 'es',
        plan: 'free',
        creditBalance: 15,
        createdAt: DateTime.now(),
      );

      expect(profile.creditBalance, 15);
      final updated = profile.copyWith(creditBalance: 12);
      expect(updated.creditBalance, 12);
      expect(updated.id, profile.id);
    });

    test('CreditTransaction parses usage and bonus types correctly', () {
      final txMap = {
        'id': 'tx-1',
        'user_id': 'user-1',
        'amount': -3,
        'transaction_type': 'usage',
        'tool': 'remove_bg',
        'description': 'Uso de herramienta: remove_bg',
        'created_at': DateTime.now().toIso8601String(),
      };

      final tx = CreditTransaction.fromMap(txMap);
      expect(tx.amount, -3);
      expect(tx.transactionType, 'usage');
      expect(tx.tool, 'remove_bg');
    });
  });
}
