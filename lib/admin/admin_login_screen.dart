import 'package:flutter/material.dart';
import 'package:passage/services/local_admin_accounts_store.dart';
import 'package:passage/services/local_auth_store.dart';
import 'package:passage/admin/admin_root.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  late final AnimationController _intro;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fadeIn = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final email = _email.text.trim();
    final pw = _password.text;

    try {
      final ok = await LocalAdminAccountsStore.verifyCredentials(email: email, password: pw);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid admin credentials')),
          );
        }
        return;
      }
      await LocalAuthStore.setLoginEmail(email);
      await LocalAuthStore.setRole(LocalAuthStore.roleAdmin);
      await LocalAuthStore.updateSessions();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminRootScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                                child: const Icon(Icons.admin_panel_settings, color: Colors.indigo),
                              ),
                              const SizedBox(width: 10),
                              Text('Passage Admin', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Sign in to the admin console', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Admin email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter email';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter password';
                              if (v.length < 6) return 'Too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _signIn,
                            icon: _submitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(_submitting ? 'Signing in...' : 'Sign in'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<List<AdminAccountModel>>(
                            future: LocalAdminAccountsStore.listAdmins(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final admins = snap.data!;
                              if (admins.isEmpty) return const SizedBox.shrink();
                              return Text(
                                'Allowed admins: ' + admins.map((e) => e.email).join(', '),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                              );
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
