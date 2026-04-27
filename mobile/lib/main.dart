import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/theme_controller.dart';
import 'package:mobile/screens/main_navigation.dart';
import 'package:mobile/screens/profile_setup_screen.dart';
import 'package:mobile/screens/welcome_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/auth_provider.dart';
import 'package:mobile/services/feed_provider.dart';
import 'package:mobile/services/notification_provider.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:mobile/screens/fullscreen_feed_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appThemeController.load();
  
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCuCZiXlmTO8xir7_zmxzGTjEM-_ixoU30",
          authDomain: "tiki-zaya.firebaseapp.com",
          projectId: "tiki-zaya",
          storageBucket: "tiki-zaya.firebasestorage.app",
          messagingSenderId: "597645618009",
          appId: "1:597645618009:web:7331fe371f64470dedba48",
          measurementId: "G-MN0P6FFQE5",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    debugPrint('✅ Firebase Initialized Successfully');
  } catch (e) {
    debugPrint('❌ Firebase Initialization Error: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: TikiZayaApp(themeController: appThemeController),
    ),
  );
}

class TikiZayaApp extends StatefulWidget {
  final ThemeController themeController;
  const TikiZayaApp({super.key, required this.themeController});

  @override
  State<TikiZayaApp> createState() => _TikiZayaAppState();
}

class _TikiZayaAppState extends State<TikiZayaApp> {
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

    // Handle incoming links when the app is running in the background or foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint('AppLinks error: $err');
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Example: https://tikizaya.com/v/123456789
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'v') {
      final videoId = uri.pathSegments[1];
      if (videoId.isNotEmpty) {
        try {
          // Fetch the single video by its ID
          final videoData = await ApiService.getVideoById(videoId);
          
          if (navigatorKey.currentState != null) {
            final auth = Provider.of<AuthProvider>(navigatorKey.currentContext!, listen: false);
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (_) => FullscreenFeedScreen(
                  videos: [videoData], // Wrap single video in list
                  initialIndex: 0,
                  currentUser: auth.user,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error handling deep link video fetch: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFFF006E),
        secondary: Color(0xFF3B82F6),
        surface: Colors.white,
      ),
      cardColor: Colors.white,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF090909),
      cardColor: const Color(0xFF15161A),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF3B8E),
        secondary: Color(0xFF8B5CF6),
        tertiary: Color(0xFF3B82F6),
        surface: Color(0xFF15161A),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF15161A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Tiki Zaya',
          debugShowCheckedModeBanner: false,
          themeMode: widget.themeController.themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: const SplashRouter(),
        );
      },
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // splash delay
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.checkAuthStatus();

    if (!mounted) return;

    if (!auth.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
      return;
    }

    final profile = auth.user ?? {};
    if (profile.isNotEmpty) {
      final pref = (profile['themePreference'] ?? '').toString();
      if (pref == 'light') {
        await appThemeController.setThemeMode(ThemeMode.light);
      } else if (pref == 'dark') {
        await appThemeController.setThemeMode(ThemeMode.dark);
      }

      if (profile.containsKey('username') && profile['username'] != null && profile['username'].toString().isNotEmpty) {
        await NotificationService.initialize();
        if (mounted) {
          if ((profile['status'] ?? '').toString() == 'blocked') {
            await auth.logout();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your account is blocked. Contact support.')),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/branding/logo.png',
                  width: 240,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Text(
                  'Share your moments',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF006E),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
