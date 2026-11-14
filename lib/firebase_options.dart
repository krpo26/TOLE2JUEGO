import 'package:firebase_core/firebase_core.dart';

/// Los valores se pasan con --dart-define desde codemagic.yaml
/// (o pégalos aquí directamente en lugar de 'PEGA_...').
class DefaultFirebaseOptions {
  static const String apiKey = String.fromEnvironment('FB_API_KEY', defaultValue: 'PEGA_API_KEY');
  static const String appId = String.fromEnvironment('FB_APP_ID', defaultValue: 'PEGA_APP_ID');
  static const String senderId = String.fromEnvironment('FB_SENDER_ID', defaultValue: 'PEGA_SENDER_ID');
  static const String projectId = String.fromEnvironment('FB_PROJECT_ID', defaultValue: 'PEGA_PROJECT_ID');
  static const String dbUrl = String.fromEnvironment('FB_DB_URL', defaultValue: 'PEGA_DATABASE_URL');

  static bool get isConfigured => !apiKey.startsWith('PEGA');

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    databaseURL: dbUrl,
  );
}
