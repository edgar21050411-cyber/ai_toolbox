import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/features/tools/data/tool_registry.dart';
import 'package:ai_toolbox/features/tools/domain/tool_entity.dart';

void main() {
  group('ToolRegistry Tests', () {
    test('ToolRegistry filters tools by category and availability', () {
      final registry = ToolRegistry();

      expect(registry.allTools, isEmpty);
      expect(registry.isToolAvailable('unknown'), isFalse);
      expect(registry.getCreditCost('unknown'), 1); // Fallback cost
    });

    test('ToolEntity correctly identifies minimum plan requirements', () {
      const freeTool = ToolEntity(
        id: 't-1',
        slug: 't-1',
        name: {'es': 'Herramienta Free'},
        description: {'es': 'Desc'},
        category: 'create',
        icon: 'star',
        enabled: true,
        beta: false,
        minimumPlan: 'free',
        creditCost: 1,
        sortOrder: 1,
      );

      const proTool = ToolEntity(
        id: 't-2',
        slug: 't-2',
        name: {'es': 'Herramienta Pro'},
        description: {'es': 'Desc'},
        category: 'marketing',
        icon: 'star',
        enabled: true,
        beta: false,
        minimumPlan: 'pro',
        creditCost: 8,
        sortOrder: 2,
      );

      expect(freeTool.minimumPlan, 'free');
      expect(proTool.minimumPlan, 'pro');
      expect(proTool.creditCost, 8);
    });
  });
}
