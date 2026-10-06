import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_toolbox/main.dart';
import 'package:ai_toolbox/features/auth/infrastructure/auth_service.dart';
import 'package:ai_toolbox/features/auth/domain/user_profile.dart';

class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isAuthenticated => false;

  @override
  bool get isLoading => false;

  @override
  UserProfile? get currentProfile => null;

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> register(String email, String password, {String? displayName}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> fetchProfile() async {}
}

void main() {
  testWidgets('AIToolboxApp root widget smoke test', (WidgetTester tester) async {
    final mockAuth = MockAuthService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: mockAuth,
        child: const AIToolboxApp(),
      ),
    );

    expect(find.byType(AIToolboxApp), findsOneWidget);
  });
}
