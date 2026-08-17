import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/bluetooth_controller.dart';
import 'providers/workout_session_provider.dart';
import 'providers/agent_provider.dart';
import 'providers/review_provider.dart';
import 'providers/chat_provider.dart';
import 'services/workout_service.dart';
import 'services/chat_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/anamnesis_screen.dart';
import 'core/constants.dart';

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/register_screen.dart';
import 'services/notification_service.dart';
import 'services/telemetry_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize OpenTelemetry
  TelemetryService().initialize(
    serviceName: AppConstants.otelServiceName,
    endpoint: AppConstants.otelEndpoint,
    headers: AppConstants.otelHeaders,
  );

  await initializeDateFormatting('pt_BR', null);

  // Register FCM background message handler before runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // PULSO — Status bar styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(AppConstants.primaryDark),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');

    // Magic Link deep link: pulso://auth/verify?token=...
    if (uri.host == 'auth' && uri.path == '/verify') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final context = _navigatorKey.currentContext;
          if (context == null) return;

          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final success = await authProvider.verifyMagicLink(token);

          if (success) {
            if (!authProvider.anamnesisCompleted && !authProvider.anamnesisSkipped) {
              _navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AnamnesisScreen()),
                (route) => false,
              );
            } else {
              _navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
              );
            }
          }
        });
      }
    }

    // Invite deep link (legacy)
    if (uri.path == '/register') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => RegisterScreen(inviteToken: token),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothController()),
        ChangeNotifierProvider(create: (context) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          return AgentProvider(authProvider.dio);
        }),
        ChangeNotifierProvider(create: (context) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final workoutService = WorkoutService(authProvider.dio);

          workoutService.syncPendingWorkouts();

          final sessionProvider = WorkoutSessionProvider(workoutService, authProvider);
          sessionProvider.restoreSession();

          return sessionProvider;
        }),
        ChangeNotifierProvider(create: (context) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          return ReviewProvider(authProvider.dio);
        }),
        ChangeNotifierProvider(create: (context) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final chatService = ChatService(authProvider.dio);
          return ChatProvider(chatService, authProvider);
        }),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'PULSO',
        debugShowCheckedModeBanner: false,
        theme: _buildPulsoTheme(),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (authProvider.isAuthenticated) {
              if (!authProvider.anamnesisCompleted && !authProvider.anamnesisSkipped) {
                return const AnamnesisScreen();
              }
              return const MainNavigationScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }

  ThemeData _buildPulsoTheme() {
    // ============================================================
    // PULSO Design System v2.0 — Dark Premium Fitness Theme
    // Primary: Violet #7C3AED | Accent: Cyan #06B6D4
    // ============================================================
    const primaryViolet = Color(AppConstants.neonAccent);       // #7C3AED
    const cyanAccent = Color(AppConstants.cyanAccent);           // #06B6D4
    const bgDeep = Color(AppConstants.primaryDark);              // #050508
    const cardBg = Color(AppConstants.cardDark);                 // #0D0C14
    const textPrimary = Color(AppConstants.textPrimary);         // #F0F2F8
    const textSecondary = Color(AppConstants.textSecondary);     // #6B6A7A
    const border = Color(AppConstants.borderColor);              // #1C1929

    // Use Space Grotesk as primary (matching web), Inter as body
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDeep,
      primaryColor: primaryViolet,

      colorScheme: ColorScheme.dark(
        primary: primaryViolet,
        secondary: cyanAccent,
        surface: cardBg,
        error: const Color(AppConstants.errorColor),
        primaryContainer: const Color(0xFF2D1B5E),   // Deep violet tint
        secondaryContainer: const Color(0xFF0A3540), // Deep cyan tint
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
        outline: border,
      ),

      // Typography
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: textSecondary, fontSize: 12),
        labelLarge: baseTextTheme.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        labelMedium: baseTextTheme.labelMedium?.copyWith(color: textSecondary),
        labelSmall: baseTextTheme.labelSmall?.copyWith(color: textSecondary),
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: bgDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primaryViolet,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(AppConstants.borderColor), width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(AppConstants.cardElevated),
        hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(color: primaryViolet, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryViolet, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(AppConstants.errorColor)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(AppConstants.errorColor), width: 2),
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryViolet,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryViolet,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryViolet,
          side: const BorderSide(color: primaryViolet, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: const Color(AppConstants.cardElevated),
        selectedColor: const Color(0xFF2D1B5E),
        labelStyle: GoogleFonts.inter(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: Color(AppConstants.borderColor)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(AppConstants.cardDark),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(AppConstants.borderColor)),
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(AppConstants.borderColor),
        thickness: 1,
        space: 0,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(AppConstants.cardElevated),
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryViolet,
        linearTrackColor: Color(AppConstants.borderColor),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryViolet;
          return const Color(AppConstants.borderColor);
        }),
      ),

      useMaterial3: true,
    );
  }
}
