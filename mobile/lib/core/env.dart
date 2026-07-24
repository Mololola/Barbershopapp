// Supplied at build/run time via --dart-define-from-file, e.g.:
//   flutter run --dart-define-from-file=env.json
// env.json is untracked (see .gitignore) — copy env.json.example and fill in
// your Supabase project's URL and anon key.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const fastApiBaseUrl = String.fromEnvironment(
    'FASTAPI_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
