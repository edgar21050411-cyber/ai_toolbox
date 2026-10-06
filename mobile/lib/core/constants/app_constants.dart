class AppConstants {
  static const String appName = 'AI Toolbox';
  static const String appVersion = '1.0.0+1';

  // Categorías estándar del catálogo
  static const List<String> categories = [
    'create',
    'improve',
    'marketing',
    'documents',
    'audio',
    'assistant',
  ];

  // Supabase Storage Buckets
  static const String avatarsBucket = 'avatars';
  static const String userFilesBucket = 'user-files';
  static const String generatedFilesBucket = 'generated-files';

  // Timeouts y límites
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxFileSizeMb = 15;
}
