/// Core constants for the PULSO mobile app
/// Design System v2.0 — "Tech Premium Fitness"
/// Primary: Violet (#7C3AED) | Accent: Cyan (#06B6D4)
class AppConstants {
  // API Configuration
  static const String apiUrl = 'https://api.pulsofit.app';
  static const String apiVersion = '/api/v1';
  static const String baseUrl = '$apiUrl$apiVersion';
  
  // API Endpoints
  static const String magicLinkEndpoint = '$baseUrl/auth/magic-link';
  static const String verifyMagicLinkEndpoint = '$baseUrl/auth/verify-magic-link';
  static const String usersEndpoint = '$baseUrl/users';
  static const String workoutsEndpoint = '$baseUrl/workouts';
  static const String workoutSessionsEndpoint = '$baseUrl/workout-sessions';
  static const String gamificationEndpoint = '$baseUrl/gamification';
  static const String studentEndpoint = '$baseUrl/student';
  static const String aiAgentEndpoint = '$baseUrl/ai-agent';
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  
  // ============================================================
  // PULSO Design System v2.0 — Dark Premium Palette
  // ============================================================
  
  /// Background: Deep Space #050508
  static const int primaryDark = 0xFF050508;
  
  /// Card background: #0D0C14
  static const int cardDark = 0xFF0D0C14;
  
  /// Elevated card: #121118
  static const int cardElevated = 0xFF121118;
  
  /// Primary Violet: #7C3AED
  static const int neonAccent = 0xFF7C3AED;
  
  /// Primary Violet Hover: #6D28D9
  static const int neonAccentHover = 0xFF6D28D9;
  
  /// Primary Violet Light (for glow): #A78BFA
  static const int neonAccentLight = 0xFFA78BFA;
  
  /// Cyan Accent (IoT / secondary): #06B6D4
  static const int cyanAccent = 0xFF06B6D4;
  
  /// Cyan Light: #67E8F9
  static const int cyanAccentLight = 0xFF67E8F9;
  
  /// Text Primary: #F0F2F8
  static const int textPrimary = 0xFFF0F2F8;
  
  /// Text Secondary: #6B6A7A
  static const int textSecondary = 0xFF6B6A7A;
  
  /// Text Muted: #4A4860
  static const int textMuted = 0xFF4A4860;
  
  /// Border: #1C1929
  static const int borderColor = 0xFF1C1929;
  
  /// Border Accent (primary tinted): #2D1B5E
  static const int borderAccent = 0xFF2D1B5E;
  
  /// Success Green: #22C55E
  static const int successColor = 0xFF22C55E;
  
  /// Warning Orange: #F59E0B  
  static const int warningColor = 0xFFF59E0B;
  
  /// Error Red: #EF4444
  static const int errorColor = 0xFFEF4444;

  // Bluetooth
  static const String mageneH303ServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String heartRateCharacteristicUuid = '00002a37-0000-1000-8000-00805f9b34fb';

  // OpenTelemetry Configuration (Proxy via Backend)
  static const String otelEndpoint = '$baseUrl/telemetry/v1/traces'; 
  static const String otelHeaders = '';  // Auth is handled by the backend proxy
  static const String otelServiceName = 'pulso-mobile';
}
