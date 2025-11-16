import 'package:flutter/material.dart';
import 'package:passage/theme.dart';
import 'package:passage/admin/admin_login_screen.dart';

/// Standalone Admin App widget.
///
/// Note: No `main()` here so this can be imported by other entrypoints
/// (e.g., lib/main.dart) without symbol conflicts.
class PassageAdminWebApp extends StatelessWidget {
  const PassageAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Passage Admin',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AdminLoginScreen(),
    );
  }
}
