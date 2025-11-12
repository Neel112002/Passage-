import 'package:flutter/material.dart';
import 'package:passage/services/auth_store.dart';

/// AuthGate ensures protected content renders only after auth is hydrated.
/// - If authReady == false -> show skeleton/loading
/// - If authReady == true && user == null -> redirect to /login
/// - Else -> render child
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _store = AuthStore.instance;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    // Ensure store is initialized (no-op if already init)
    _store.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        if (!_store.authReady) {
          // Hydrating; render a lightweight skeleton, no redirects
          return const _AuthSkeleton();
        }
        if (_store.authReady && _store.user == null) {
          // Only redirect once to avoid loops
          if (!_redirected) {
            _redirected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            });
          }
          return const _AuthSkeleton();
        }
        // Auth OK
        return widget.child;
      },
    );
  }
}

class _AuthSkeleton extends StatelessWidget {
  const _AuthSkeleton();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text('Loading…', style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
