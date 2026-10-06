import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/features/credits/data/credit_service.dart';

void main() {
  group('CreditService Logic Tests', () {
    test('canAfford accurately checks balances', () {
      final creditService = CreditService();

      // Initial cached balance is 0
      expect(creditService.balance, 0);
      expect(creditService.canAfford(1), isFalse);
      expect(creditService.canAfford(0), isTrue);
    });
  });
}
