import 'supabase_config.dart';

class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: SupabaseConfig.url,
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: SupabaseConfig.publishableKey,
  );
  static const oauthRedirect = 'io.omnirush.caloriescan://login-callback';

  static bool get supabaseConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    return supabaseUrl.isNotEmpty &&
        supabasePublishableKey.isNotEmpty &&
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }
}
