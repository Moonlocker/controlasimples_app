class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qdhnhukjhgethxrnvhce.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkaG5odWtqaGdldGh4cm52aGNlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2MDAzNjYsImV4cCI6MjEwMzE3NjM2Nn0.vsfQXjmlX74aDnf3XGpEQuTNW3goBy_HLXUdOoOkgSU',
  );

  static const String appName = 'Controla Simples';
  static const String currency = 'BRL';
  static const String locale = 'pt_BR';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://controlasimples.com.br',
  );

  static const String oauthRedirect = 'controlasimples://login-callback';
}
