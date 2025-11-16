import 'package:flutter/material.dart';
import 'package:passage/services/local_auth_store.dart';
import 'package:passage/admin/admin_dashboard_screen.dart';
import 'package:passage/admin/admin_login_screen.dart';

/// Dedicated Admin entry point. Only accessible when role == admin.
class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final isAdmin = await LocalAuthStore.isAdmin();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _allowed = isAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed) {
      // If not admin, show the dedicated Admin login screen (web-only admin app)
      return const AdminLoginScreen();
    }

    // Admin UI shell; for now, just show the dashboard with an Admin-only AppBar action for logout
    return Scaffold(
      body: const AdminDashboardScreen(),
      appBar: AppBar(
        title: const Text('Passage Admin'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              // Reset role to user and clear minimal auth state for demo logout
              await LocalAuthStore.setRole(LocalAuthStore.roleUser);
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}
