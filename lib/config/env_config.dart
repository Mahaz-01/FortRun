import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ============================================================
/// EnvConfig — Safely reads API keys and credentials from .env.
///
/// All sensitive values are loaded at startup via `dotenv.load()`
/// in main.dart. This class provides typed, validated access
/// with clear error messages when a key is missing.
/// ============================================================

class EnvConfig {
  EnvConfig._(); // Prevent instantiation

  // ── Supabase Credentials ────────────────────────────────────

  /// Supabase project URL (e.g. https://abc123.supabase.co)
  static String get supabaseUrl {
    final val = dotenv.env['SUPABASE_URL'];
    if (val == null || val.isEmpty || val.contains('your-project-id')) {
      throw Exception(
        'SUPABASE_URL is not set.\n'
        'Open .env and replace the placeholder with your Supabase project URL.\n'
        'Find it at: https://supabase.com/dashboard → Project Settings → API',
      );
    }
    return val;
  }

  /// Supabase anonymous (public) key — safe for client-side use with RLS.
  static String get supabaseAnonKey {
    final val = dotenv.env['SUPABASE_ANON_KEY'];
    if (val == null || val.isEmpty || val.contains('your_supabase')) {
      throw Exception(
        'SUPABASE_ANON_KEY is not set.\n'
        'Open .env and replace the placeholder with your Supabase anon key.\n'
        'Find it at: https://supabase.com/dashboard → Project Settings → API',
      );
    }
    return val;
  }

  // Google API keys removed — FortRun uses OpenStreetMap (flutter_map +
  // Overpass), which needs no API key. Restaurant lookups in the sabotage
  // feature come from RestaurantService via the free Overpass API.
}
