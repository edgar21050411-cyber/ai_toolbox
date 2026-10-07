import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/environment.dart';
import 'core/config/supabase_config.dart';
import 'core/i18n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/infrastructure/auth_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/credits/data/credit_service.dart';
import 'features/history/data/history_repository.dart';
import 'features/home/presentation/screens/main_navigation_screen.dart';
import 'features/projects/data/projects_repository.dart';
import 'features/tools/data/tool_registry.dart';
import 'services/ai/ai_router.dart';
import 'services/analytics/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar configuracion de entorno
  EnvConfig.initialize();

  // 2. Inicializar Supabase cliente
  await SupabaseConfig.initialize();

  // 3. Registrar Analytics inicial
  await AnalyticsService().logAppOpened();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CreditService()),
        ChangeNotifierProvider(create: (_) => ToolRegistry()),
        ChangeNotifierProvider(create: (_) => ProjectsRepository()),
        ChangeNotifierProvider(create: (_) => HistoryRepository()),
        Provider(create: (_) => AIRouter()),
      ],
      child: const AIToolboxApp(),
    ),
  );
}

class AIToolboxApp extends StatelessWidget {
  const AIToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return MaterialApp(
      title: 'AI Toolbox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', ''),
        Locale('en', ''),
      ],
      home: authService.isAuthenticated ? const MainNavigationScreen() : const LoginScreen(),
    );
  }
}
