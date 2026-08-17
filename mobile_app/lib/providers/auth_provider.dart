import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants.dart';
import '../services/notification_service.dart';
import '../services/telemetry_service.dart';

/// Custom interceptor for handling auth tokens and automatic refresh
class _AuthTokenInterceptor extends Interceptor {
  final AuthProvider authProvider;
  final Dio dio;
  final FlutterSecureStorage storage;
  bool _isRefreshing = false;
  late Future<bool> _refreshFuture;

  _AuthTokenInterceptor(this.authProvider, this.dio, this.storage);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip adding Authorization header to refresh-token endpoint
    if (!options.path.contains('/auth/refresh-token')) {
      if (authProvider._accessToken != null) {
        options.headers['Authorization'] = 'Bearer ${authProvider._accessToken}';
        debugPrint('📤 Adding token to request: ${options.path} (token exists: ${authProvider._accessToken != null})');
      } else {
        debugPrint('⚠️ No access token available for request: ${options.path}');
      }
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(DioException error, ErrorInterceptorHandler handler) async {
    // Only handle 401 for non-refresh-token endpoints
    if (error.response?.statusCode != 401 || error.requestOptions.path.contains('/auth/refresh-token')) {
      return handler.next(error);
    }

    debugPrint('⚠️ 401 Unauthorized — attempting token refresh...');

    // Prevent multiple simultaneous refresh attempts
    if (_isRefreshing) {
      debugPrint('⏳ Token refresh already in progress, waiting...');
      final success = await _refreshFuture;

      if (success) {
        // Retry original request with refreshed token
        error.requestOptions.headers['Authorization'] = 'Bearer ${authProvider._accessToken}';
        try {
          final retryResponse = await dio.fetch(error.requestOptions);
          return handler.resolve(retryResponse);
        } catch (e) {
          debugPrint('⚠️ Retry failed after token refresh: $e');
          return handler.next(error);
        }
      } else {
        return handler.next(error);
      }
    }

    // Start token refresh
    _isRefreshing = true;
    _refreshFuture = _performTokenRefresh();

    final success = await _refreshFuture;

    if (success) {
      // Retry original request with new token
      error.requestOptions.headers['Authorization'] = 'Bearer ${authProvider._accessToken}';
      try {
        final retryResponse = await dio.fetch(error.requestOptions);
        return handler.resolve(retryResponse);
      } catch (e) {
        debugPrint('⚠️ Retry failed after token refresh: $e');
        return handler.next(error);
      }
    } else {
      return handler.next(error);
    }
  }

  /// Perform token refresh and return success status
  Future<bool> _performTokenRefresh() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');

      if (refreshToken == null) {
        debugPrint('❌ No refresh token available');
        authProvider.logout();
        return false;
      }

      debugPrint('🔄 Refreshing access token using refresh_token: ${refreshToken.substring(0, 20)}...');

      // Create a separate Dio instance without interceptors to avoid loops
      final cleanDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));

      try {
        final response = await cleanDio.post(
          '${AppConstants.baseUrl}/auth/refresh-token',
          queryParameters: {'refresh_token': refreshToken},
        );

        if (response.statusCode == 200) {
          debugPrint('✅ Refresh endpoint returned status 200');
          debugPrint('📦 Response body: ${response.data}');

          final newAccessToken = response.data['access_token'];
          final newRefreshToken = response.data['refresh_token'];

          if (newAccessToken == null || newAccessToken.isEmpty) {
            debugPrint('❌ Access token is null or empty!');
            return false;
          }

          debugPrint('💾 Saving tokens to storage...');
          debugPrint('   - Access token length: ${newAccessToken.length} chars, preview: ${newAccessToken.substring(0, 20)}...');
          debugPrint('   - Refresh token length: ${newRefreshToken?.length ?? 0} chars');

          // Save to storage first
          try {
            await storage.write(key: AppConstants.accessTokenKey, value: newAccessToken);
            await storage.write(key: 'refresh_token', value: newRefreshToken);
            debugPrint('✅ Tokens saved to storage');
          } catch (storageError) {
            debugPrint('❌ Failed to save tokens to storage: $storageError');
            return false;
          }

          // Then update in-memory token
          authProvider._accessToken = newAccessToken;
          debugPrint('✅ In-memory token updated. New token: ${newAccessToken.substring(0, 20)}...');

          return true;
        }

        debugPrint('❌ Token refresh returned status ${response.statusCode}: ${response.statusMessage}');
        authProvider.logout();
        return false;
      } on DioException catch (dioError) {
        debugPrint('❌ Token refresh request failed: ${dioError.response?.statusCode} - ${dioError.response?.data}');
        authProvider.logout();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Token refresh exception: $e');
      authProvider.logout();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }
}

/// Authentication state and logic provider — Magic Link based
class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  
  String? _accessToken;
  String? _userId;
  String? _userEmail;
  String? _fullName;
  String? _photoUrl;
  String? _userRole;
  String? _trainerLogoUrl;
  String? _instagramHandle;
  String? _gender;
  String? _whatsappNumber;
  double? _weightKg;
  DateTime? _birthday;
  Map<String, dynamic>? _medicalHistory;
  bool _anamnesisCompleted = false;
  bool _anamnesisSkipped = false;
  bool _acceptedAiTerms = false;
  int _xpPoints = 0;
  int _level = 1;
  int _currentStreak = 0;
  String? _subscriptionStatus;
  String? _subscriptionPlanName;
  int? _aiRequestsRemaining;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Magic link state
  bool _magicLinkSent = false;
  String? _pendingEmail;
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get accessToken => _accessToken;
  String? get token => _accessToken;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get fullName => _fullName;
  String? get photoUrl => _photoUrl;
  String? get userRole => _userRole;
  String? get trainerLogoUrl => _trainerLogoUrl;
  String? get instagramHandle => _instagramHandle;
  String? get gender => _gender;
  String? get whatsappNumber => _whatsappNumber;
  double? get weightKg => _weightKg;
  DateTime? get birthday => _birthday;
  Map<String, dynamic>? get medicalHistory => _medicalHistory;
  bool get anamnesisCompleted => _anamnesisCompleted;
  bool get anamnesisSkipped => _anamnesisSkipped;
  bool get acceptedAiTerms => _acceptedAiTerms;
  bool get isTrainer => _userRole == 'TRAINER';
  bool get isStudent => _userRole == 'STUDENT';
  int get xpPoints => _xpPoints;
  int get level => _level;
  int get currentStreak => _currentStreak;
  bool get magicLinkSent => _magicLinkSent;
  String? get pendingEmail => _pendingEmail;
  String? get subscriptionStatus => _subscriptionStatus;
  String? get subscriptionPlanName => _subscriptionPlanName;
  int? get aiRequestsRemaining => _aiRequestsRemaining;
  
  // Trainer info for students
  String? _trainerBrandName;
  String? _trainerPrimaryColor;
  String? _trainerWhatsappNumber;
  
  String? _trainerId;
  
  String? get trainerBrandName => _trainerBrandName;
  String? get trainerPrimaryColor => _trainerPrimaryColor;
  String? get trainerWhatsappNumber => _trainerWhatsappNumber;
  String? get trainerId => _trainerId;
  
  bool get hasTrainer => isStudent && _trainerId != null;

  void skipAnamnesis() {
    _anamnesisSkipped = true;
    notifyListeners();
  }

  void completeAnamnesis() {
    _anamnesisCompleted = true;
    _storage.write(key: 'anamnesis_completed', value: 'true');
    notifyListeners();
  }

  Future<void> acceptAiTerms() async {
    await _dio.post('${AppConstants.usersEndpoint}/accept-ai-terms');
    _acceptedAiTerms = true;
    await _storage.write(key: 'accepted_ai_terms', value: 'true');
    notifyListeners();
  }
  
  // ── Global Refresh Trigger ─────────────────────────────────────────
  // Used by IndexedStack screens to reload data when an action occurs in another tab
  // (e.g. accepting a student in the home tab should refresh the students tab)
  int _syncPulse = 0;
  int get syncPulse => _syncPulse;

  void triggerSync() {
    _syncPulse++;
    notifyListeners();
  }

  AuthProvider({FlutterSecureStorage? storage, Dio? dio}) 
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? Dio() {
    _initializeDio();
    _loadStoredCredentials();
  }
  
  /// Get full profile image URL
  String? getProfileImageUrl() {
    if (_photoUrl == null) return null;
    if (_photoUrl!.startsWith('http')) return _photoUrl;
    final baseUrl = AppConstants.baseUrl.replaceAll('/api/v1', '');
    return '$baseUrl$_photoUrl';
  }

  /// Get full trainer logo URL
  String? getTrainerLogoUrl() {
    if (_trainerLogoUrl == null) return null;
    if (_trainerLogoUrl!.startsWith('http')) return _trainerLogoUrl;
    final baseUrl = AppConstants.baseUrl.replaceAll('/api/v1', '');
    return '$baseUrl$_trainerLogoUrl';
  }
  
  /// Initialize Dio with default configuration
  void _initializeDio() {
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    
    // Add OpenTelemetry tracing
    _dio.interceptors.add(TelemetryService().dioInterceptor);
    
    // Add interceptor to include auth token and handle token refresh
    _dio.interceptors.add(
      _AuthTokenInterceptor(this, _dio, _storage),
    );
  }
  
  /// Load stored credentials on app start
  Future<void> _loadStoredCredentials() async {
    try {
      _accessToken = await _storage.read(key: AppConstants.accessTokenKey);
      _userId = await _storage.read(key: AppConstants.userIdKey);
      _userEmail = await _storage.read(key: AppConstants.userEmailKey);
      _fullName = await _storage.read(key: 'user_full_name');
      _photoUrl = await _storage.read(key: 'user_photo_url');
      _userRole = await _storage.read(key: 'user_role');
      _trainerLogoUrl = await _storage.read(key: 'trainer_logo_url');
      _instagramHandle = await _storage.read(key: 'instagram_handle');
      _gender = await _storage.read(key: 'user_gender');
      _whatsappNumber = await _storage.read(key: 'user_whatsapp_number');
      final anamnesisStr = await _storage.read(key: 'anamnesis_completed');
      _anamnesisCompleted = anamnesisStr == 'true';

      final aiTermsStr = await _storage.read(key: 'accepted_ai_terms');
      _acceptedAiTerms = aiTermsStr == 'true';
      
      final xpStr = await _storage.read(key: 'user_xp');
      _xpPoints = xpStr != null ? int.tryParse(xpStr) ?? 0 : 0;
      
      final levelStr = await _storage.read(key: 'user_level');
      _level = levelStr != null ? int.tryParse(levelStr) ?? 1 : 1;
      
      final streakStr = await _storage.read(key: 'current_streak');
      _currentStreak = streakStr != null ? int.tryParse(streakStr) ?? 0 : 0;
      
      _trainerBrandName = await _storage.read(key: 'trainer_brand_name');
      _trainerPrimaryColor = await _storage.read(key: 'trainer_primary_color');
      _trainerWhatsappNumber = await _storage.read(key: 'trainer_whatsapp_number');
      _trainerId = await _storage.read(key: 'trainer_id');
      _subscriptionStatus = await _storage.read(key: 'subscription_status');
      _subscriptionPlanName = await _storage.read(key: 'subscription_plan_name');
      final aiCreditsStr = await _storage.read(key: 'ai_requests_remaining');
      _aiRequestsRemaining = aiCreditsStr != null ? int.tryParse(aiCreditsStr) : null;

      // Restore weight/birthday so offline-started workouts compute calories
      // with the real user data instead of falling back to 75kg / age 30.
      final weightStr = await _storage.read(key: 'user_weight_kg');
      if (weightStr != null) _weightKg = double.tryParse(weightStr);
      final birthdayStr = await _storage.read(key: 'user_birthday');
      if (birthdayStr != null) _birthday = DateTime.tryParse(birthdayStr);

      if (_accessToken != null) {
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading stored credentials: $e');
    }
  }

  // ── Magic Link: Step 1 — Request ─────────────────────
  /// Request a magic link to be sent to the user's email
  Future<bool> requestMagicLink(String email, String role) async {
    _isLoading = true;
    _errorMessage = null;
    _magicLinkSent = false;
    notifyListeners();

    try {
      final response = await _dio.post(
        AppConstants.magicLinkEndpoint,
        data: {
          'email': email.trim().toLowerCase(),
          'desired_role': role,
        },
      );

      if (response.statusCode == 200) {
        _magicLinkSent = true;
        _pendingEmail = email.trim().toLowerCase();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _isLoading = false;
      if (e.response?.statusCode == 422) {
        _errorMessage = 'Por favor, insira um e-mail válido';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _errorMessage = 'Timeout de conexão. Verifique sua internet.';
      } else if (e.type == DioExceptionType.connectionError) {
        _errorMessage = 'Não foi possível conectar ao servidor.';
      } else {
        _errorMessage = 'Erro ao enviar o link mágico. Tente novamente.';
      }
      debugPrint('Magic link request error: ${e.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Ocorreu um erro inesperado';
      debugPrint('Unexpected magic link error: $e');
      notifyListeners();
      return false;
    }

    _isLoading = false;
    _errorMessage = 'Falha ao enviar o link mágico';
    notifyListeners();
    return false;
  }

  // ── Magic Link: Step 2 — Verify ──────────────────────
  /// Verify the magic link token and authenticate the user
  Future<bool> verifyMagicLink(String? token) async {
    if (token == null || token.isEmpty) {
      _errorMessage = 'Por favor, insira o código';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> payload = {
        'token': token.trim(),
      };
      
      if (_pendingEmail != null && _pendingEmail!.isNotEmpty) {
        payload['email'] = _pendingEmail!.trim().toLowerCase();
      }

      final response = await _dio.post(
        AppConstants.verifyMagicLinkEndpoint,
        data: payload,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        // Store tokens securely
        await _storage.write(
          key: AppConstants.accessTokenKey,
          value: _accessToken,
        );
        if (refreshToken != null) {
          await _storage.write(
            key: 'refresh_token',
            value: refreshToken,
          );
        }
        if (_pendingEmail != null) {
          await _storage.write(
            key: AppConstants.userEmailKey,
            value: _pendingEmail,
          );
        }

        // Fetch user details
        await fetchUserDetails();

        // Register FCM token for push notifications
        NotificationService.initialize(_dio).catchError((_) {});

        _isAuthenticated = true;
        _magicLinkSent = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _isLoading = false;
      if (e.response?.statusCode == 400) {
        final detail = e.response?.data['detail'] ?? '';
        if (detail.toString().contains('expired')) {
          _errorMessage = 'Link mágico expirado. Solicite um novo.';
        } else if (detail.toString().contains('already been used')) {
          _errorMessage = 'Este link já foi utilizado. Solicite um novo.';
        } else {
          _errorMessage = 'Link mágico inválido. Solicite um novo.';
        }
      } else {
        _errorMessage = 'Erro ao verificar o link mágico.';
      }
      debugPrint('Magic link verify error: ${e.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Ocorreu um erro inesperado';
      debugPrint('Unexpected verify error: $e');
      notifyListeners();
      return false;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Sign in with Google
  Future<bool> loginWithGoogle(String role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: '726371618409-9qphik49ukdgukbsm9ooruigtbjpbjbr.apps.googleusercontent.com',
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        _isLoading = false;
        notifyListeners();
        return false; // user cancelled
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _isLoading = false;
        _errorMessage = 'Não foi possível obter o token do Google.';
        notifyListeners();
        return false;
      }

      final response = await _dio.post(
        '${AppConstants.baseUrl}/auth/google',
        data: {
          'id_token': idToken,
          'desired_role': role,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'];
        await _storage.write(key: AppConstants.accessTokenKey, value: _accessToken);
        if (data['refresh_token'] != null) {
          await _storage.write(key: 'refresh_token', value: data['refresh_token']);
        }

        await fetchUserDetails();
        NotificationService.initialize(_dio).catchError((_) {});

        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data['detail'] ?? 'Erro ao entrar com Google.';
      debugPrint('Google login error: ${e.message}');
    } catch (e) {
      _errorMessage = 'Ocorreu um erro inesperado.';
      debugPrint('Google login unexpected error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Reset magic link state (go back to email input)
  void resetMagicLink() {
    _magicLinkSent = false;
    _pendingEmail = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Get invite details
  Future<Map<String, dynamic>?> getInviteDetails(String token) async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/invites/$token');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching invite details: $e');
    }
    return null;
  }
  
  /// Fetch user details after login
  Future<void> fetchUserDetails() async {
    try {
      final response = await _dio.get('${AppConstants.usersEndpoint}/me');
      
      if (response.statusCode == 200) {
        final userData = response.data;
        _userId = userData['id'].toString();
        _userEmail = userData['email'];
        _fullName = userData['full_name'];
        _photoUrl = userData['photo_url'];
        _userRole = userData['role'];
        _gender = userData['gender'];
        _whatsappNumber = userData['whatsapp_number'];
        if (userData['weight_kg'] != null) {
          _weightKg = (userData['weight_kg'] as num).toDouble();
          await _storage.write(key: 'user_weight_kg', value: _weightKg.toString());
        }
        if (userData['birthday'] != null) {
          _birthday = DateTime.parse(userData['birthday']);
          await _storage.write(key: 'user_birthday', value: _birthday!.toIso8601String());
        }
        _medicalHistory = userData['medical_history'] is Map
            ? Map<String, dynamic>.from(userData['medical_history'])
            : null;
        _anamnesisCompleted = userData['anamnesis_completed'] ?? false;
        _xpPoints = userData['xp_points'] ?? 0;
        _level = userData['level'] ?? 1;
        _currentStreak = userData['current_streak'] ?? 0;
        _subscriptionStatus = userData['subscription_status'];
        _subscriptionPlanName = userData['plan_name'];
        _aiRequestsRemaining = userData['ai_requests_remaining'];
        
        if (userData['trainer_logo_url'] != null) {
          _trainerLogoUrl = userData['trainer_logo_url'];
          await _storage.write(key: 'trainer_logo_url', value: _trainerLogoUrl);
        } else if (userData['trainer_profile'] != null && userData['trainer_profile']['logo_url'] != null) {
          _trainerLogoUrl = userData['trainer_profile']['logo_url'];
          await _storage.write(key: 'trainer_logo_url', value: _trainerLogoUrl);
        }

        if (userData['trainer_profile'] != null && userData['trainer_profile']['instagram_handle'] != null) {
          _instagramHandle = userData['trainer_profile']['instagram_handle'];
          await _storage.write(key: 'instagram_handle', value: _instagramHandle);
        }
        
        if (userData['trainer_id'] != null) {
          _trainerId = userData['trainer_id'].toString();
        } else if (userData['trainer_profile'] != null && userData['trainer_profile']['user_id'] != null) {
          _trainerId = userData['trainer_profile']['user_id'].toString();
        }

        if (_trainerId != null) {
          await _storage.write(key: 'trainer_id', value: _trainerId);
        }

        // Populate trainer info (for students linked to trainer, and for trainers themselves)
        if (_userRole == 'TRAINER' && userData['trainer_profile'] != null) {
          // For trainers: load brand_name from their own profile
          _trainerBrandName = userData['trainer_profile']['brand_name'];
          _trainerPrimaryColor = userData['trainer_profile']['primary_color'];
          _trainerWhatsappNumber = userData['trainer_profile']['whatsapp_number'];

          if (_trainerBrandName != null) await _storage.write(key: 'trainer_brand_name', value: _trainerBrandName);
          if (_trainerPrimaryColor != null) await _storage.write(key: 'trainer_primary_color', value: _trainerPrimaryColor);
          if (_trainerWhatsappNumber != null) await _storage.write(key: 'trainer_whatsapp_number', value: _trainerWhatsappNumber);
        } else if (_userRole == 'STUDENT' && userData['trainer_brand_name'] != null) {
          // For students: load trainer info from user data
          _trainerBrandName = userData['trainer_brand_name'];
          _trainerPrimaryColor = userData['trainer_primary_color'];
          _trainerWhatsappNumber = userData['trainer_whatsapp_number'];

          await _storage.write(key: 'trainer_brand_name', value: _trainerBrandName);
          if (_trainerPrimaryColor != null) await _storage.write(key: 'trainer_primary_color', value: _trainerPrimaryColor);
          if (_trainerWhatsappNumber != null) await _storage.write(key: 'trainer_whatsapp_number', value: _trainerWhatsappNumber);
        }

        await _storage.write(
          key: AppConstants.userIdKey,
          value: _userId,
        );
        
        if (_fullName != null) {
          await _storage.write(key: 'user_full_name', value: _fullName);
        }
        
        if (_photoUrl != null) {
          await _storage.write(key: 'user_photo_url', value: _photoUrl);
        }
        
        if (_userRole != null) {
          await _storage.write(key: 'user_role', value: _userRole);
        }
        
        if (_gender != null) {
          await _storage.write(key: 'user_gender', value: _gender);
        }
        
        if (_whatsappNumber != null) {
          await _storage.write(key: 'user_whatsapp_number', value: _whatsappNumber);
        }

        await _storage.write(key: 'anamnesis_completed', value: _anamnesisCompleted.toString());
        await _storage.write(key: 'user_xp', value: _xpPoints.toString());
        await _storage.write(key: 'user_level', value: _level.toString());
        await _storage.write(key: 'current_streak', value: _currentStreak.toString());
        if (_subscriptionStatus != null) await _storage.write(key: 'subscription_status', value: _subscriptionStatus);
        if (_subscriptionPlanName != null) await _storage.write(key: 'subscription_plan_name', value: _subscriptionPlanName);
        if (_aiRequestsRemaining != null) await _storage.write(key: 'ai_requests_remaining', value: _aiRequestsRemaining.toString());
        // Sync AI terms acceptance from backend
        final aiTermsAccepted = userData['accepted_ai_terms_at'] != null;
        if (aiTermsAccepted && !_acceptedAiTerms) {
          _acceptedAiTerms = true;
          await _storage.write(key: 'accepted_ai_terms', value: 'true');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
    }
  }

  /// Update user profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _dio.put(
        '${AppConstants.usersEndpoint}/me',
        data: data,
      );
      
      if (response.statusCode == 200) {
        await fetchUserDetails();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _errorMessage = 'Failed to update profile';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Logout and clear stored credentials
  Future<void> logout() async {
    // Unregister FCM token before clearing credentials
    await NotificationService.unregisterToken(_dio).catchError((_) {});

    _accessToken = null;
    _userId = null;
    _userEmail = null;
    _photoUrl = null;
    _userRole = null;
    _trainerLogoUrl = null;
    _trainerBrandName = null;
    _currentStreak = 0;
    _isAuthenticated = false;
    _magicLinkSent = false;
    _pendingEmail = null;

    // Delete all auth tokens (both access and refresh)
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: AppConstants.userIdKey);
    await _storage.delete(key: AppConstants.userEmailKey);
    await _storage.delete(key: 'user_full_name');
    await _storage.delete(key: 'user_photo_url');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'trainer_logo_url');
    await _storage.delete(key: 'instagram_handle');
    _instagramHandle = null;
    await _storage.delete(key: 'user_gender');
    await _storage.delete(key: 'user_whatsapp_number');
    await _storage.delete(key: 'anamnesis_completed');
    await _storage.delete(key: 'accepted_ai_terms');
    await _storage.delete(key: 'user_xp');
    await _storage.delete(key: 'user_level');
    await _storage.delete(key: 'current_streak');
    await _storage.delete(key: 'trainer_brand_name');
    await _storage.delete(key: 'trainer_primary_color');
    await _storage.delete(key: 'trainer_whatsapp_number');
    await _storage.delete(key: 'trainer_id');
    await _storage.delete(key: 'subscription_status');
    await _storage.delete(key: 'subscription_plan_name');
    await _storage.delete(key: 'ai_requests_remaining');
    _subscriptionStatus = null;
    _subscriptionPlanName = null;
    _aiRequestsRemaining = null;

    notifyListeners();
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Get configured Dio instance for API calls
  Dio get dio => _dio;
}
