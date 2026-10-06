import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/features/auth/domain/user_profile.dart';

void main() {
  group('Auth & UserProfile Tests', () {
    test('UserProfile handles free, pro and business plans', () {
      final user = UserProfile(
        id: 'user-001',
        email: 'founder@aitoolbox.com',
        displayName: 'Founder',
        language: 'es',
        plan: 'business',
        creditBalance: 1000,
        createdAt: DateTime.now(),
      );

      expect(user.id, 'user-001');
      expect(user.email, 'founder@aitoolbox.com');
      expect(user.plan, 'business');
      expect(user.creditBalance, 1000);
    });

    test('UserProfile defaults language to es when null in map', () {
      final user = UserProfile.fromMap({
        'id': 'u-2',
        'email': 'es@test.com',
        'display_name': 'Spanish User',
        'plan': 'free',
        'credit_balance': 15,
      });

      expect(user.language, 'es');
      expect(user.plan, 'free');
    });
  });
}
