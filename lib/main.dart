import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:passage/firebase_options.dart';
import 'package:passage/theme.dart';
import 'package:passage/screens/login_screen.dart';
import 'package:passage/screens/signup_screen.dart';
import 'package:passage/screens/home_screen.dart';

import 'package:passage/services/local_cart_store.dart';
import 'package:passage/services/local_points_store.dart';
import 'package:passage/services/navigation_service.dart';
import 'package:passage/admin/admin_app.dart';
import 'package:passage/services/local_auth_store.dart';
import 'package:passage/services/local_user_profile_store.dart';
import 'package:passage/models/user_profile.dart';
import 'package:passage/services/perf_monitor.dart';
import 'package:flutter/painting.dart';
import 'screens/conversations_list_screen.dart';
import 'package:passage/services/auth_store.dart';
import 'package:passage/widgets/auth_gate.dart';
import 'package:passage/screens/debug_panel_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Light tuning of the image cache to reduce evictions that can cause jank.
  try {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 2000; // number of images
    cache.maximumSizeBytes = 300 << 20; // ~300 MB budget
  } catch (_) {}

  // Start performance monitor (prints PERF lines to the console periodically)
  PerformanceMonitor.init();

  // If running on Web and the URL indicates admin mode, boot the Admin web app.
  if (_shouldRunAdminWeb()) {
    runApp(const PassageAdminWebApp());
    return;
  }

  await LocalCartStore.bootstrap();
  await LocalPointsStore.bootstrap();
  // Initialize global auth store and subscribe to auth state (web: LOCAL persistence)
  await AuthStore.instance.init();
  await _seedDemoAccountsIfEmpty();
  runApp(const MyApp());
}

Future<void> _seedDemoAccountsIfEmpty() async {
  // Seed a default consumer user if none configured
  try {
    final existingEmail = await LocalAuthStore.getLoginEmail();
    final hasPw = await LocalAuthStore.hasPassword();
    if ((existingEmail.isEmpty) && !hasPw) {
      const demoEmail = 'user@passage.app';
      const demoPassword = 'Passage123';
      await LocalAuthStore.setLoginEmail(demoEmail);
      await LocalAuthStore.setPassword(demoPassword);
      await LocalAuthStore.setRole(LocalAuthStore.roleUser);
      await LocalAuthStore.updateSessions();
      final now = DateTime.now();
      await LocalUserProfileStore.save(
        UserProfile(
          fullName: 'Demo User',
          username: 'demo.user',
          email: demoEmail,
          phone: '',
          bio: '',
          gender: '',
          dob: null,
          avatarUrl: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  } catch (_) {}
}

bool _shouldRunAdminWeb() {
  if (!kIsWeb) return false;
  final uri = Uri.base;
  final hasAdminQuery = uri.queryParameters['admin'] == '1' || uri.queryParameters.containsKey('admin');
  final path = '/${uri.pathSegments.join('/')}';
  final hasAdminPath = path.startsWith('/admin') || path.contains('/admin/');
  return hasAdminQuery || hasAdminPath;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNavigation.navigatorKey,
      navigatorObservers: [AppRouteTracker.instance],
      title: 'Passage - E-Commerce App',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        // Protected routes behind AuthGate
        '/home': (_) => AuthGate(child: const HomeScreen()),
         '/dashboard': (_) => AuthGate(child: const HomeScreen()),
        '/messages': (_) => AuthGate(child: const ConversationsListScreen()),
        // Debug panel
        '/debug': (_) => const DebugPanelScreen(),
        // AI assistant removed
      },
      // AI overlay removed
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
