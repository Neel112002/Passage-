import 'package:flutter/material.dart';
import 'package:passage/services/local_auth_store.dart';
import 'package:passage/screens/forgot_password_screen.dart';
import 'package:passage/utils/responsive.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
// import 'package:firebase_core/firebase_core.dart' as fcore;
import 'package:passage/services/auth_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Removed: _runAuthDebug() and footer label – no functional changes to auth flow

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // Always authenticate as a consumer via Firebase Auth.
      // Seller access is available from the profile > Seller Profile flow.
      final normalizedInput = email.toLowerCase();
      await FirebaseAuthService.signInWithEmail(email: normalizedInput, password: password);

      // Keep local compatibility so screens that read LocalAuthStore still work
      try {
        await LocalAuthStore.setLoginEmail(normalizedInput);
        await LocalAuthStore.setRole(LocalAuthStore.roleUser);
        await LocalAuthStore.updateSessions();
      } catch (_) {}

      // Standardize sign-in: write into AuthStore immediately
      final u = FirebaseAuthService.currentUser;
      if (u != null) {
        AuthStore.instance.setSignedIn(
          id: u.uid,
          email: u.email,
          role: 'user',
          companyId: null,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Surface the real auth error when possible
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString())));
      return;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome')));
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _signInWithGoogle() async {
    if (_isGoogleSubmitting) return;
    setState(() => _isGoogleSubmitting = true);
    try {
      final user = await FirebaseAuthService.signInWithGoogle();
      if (user == null) {
        // Cancelled by user
        return;
      }
      // Keep local compatibility so screens that read LocalAuthStore still work
      try {
        final email = (user.email ?? '').toLowerCase();
        if (email.isNotEmpty) {
          await LocalAuthStore.setLoginEmail(email);
        }
        await LocalAuthStore.setRole(LocalAuthStore.roleUser);
        await LocalAuthStore.updateSessions();
      } catch (_) {}

      // Standardize sign-in: write to AuthStore
      AuthStore.instance.setSignedIn(
        id: user.uid,
        email: user.email,
        role: 'user',
        companyId: null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome')));
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    } on AccountExistsWithDifferentCredentialException catch (ex) {
      if (!mounted) return;
      // Offer to continue with the existing provider; linking will occur after sign-in.
      final providers = ex.providers;
      final email = ex.email;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        builder: (context) {
          final theme = Theme.of(context);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account already exists', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('An account for '+email+' exists with a different sign-in method. Continue with an existing provider to link Google afterward.'),
                  const SizedBox(height: 16),
                  ...providers.map((p) {
                    final label = _providerLabel(p);
                    final icon = _providerIcon(p);
                    final supported = p == 'password' || p == 'google.com';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: supported ? () {
                          Navigator.of(context).pop(p);
                        } : null,
                        icon: Icon(icon, color: theme.colorScheme.onPrimary),
                        label: Text('Continue with '+label),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    );
                  }).toList(),
                  if (providers.isEmpty)
                    Text('No providers returned. Please try signing in with your email & password to link Google.'),
                ],
              ),
            ),
          );
        },
      ).then((selected) async {
        if (!mounted) return;
        if (selected == 'password') {
          // Prefill email and focus password; linking will auto-run after sign-in
          setState(() {
            _emailController.text = email;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in with your password, then Google will be linked.')));
        } else if (selected == 'google.com') {
          // Retry Google sign-in; if still conflicting, user must choose password.
          await _signInWithGoogle();
        }
      });
    } on fb.FirebaseAuthException catch (e) {
      if (!mounted) return;
      final code = e.code;
      final msg = e.message ?? 'Authentication error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('['+code+'] '+msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  String _providerLabel(String providerId) {
    switch (providerId) {
      case 'password':
        return 'Email & Password';
      case 'google.com':
        return 'Google';
      case 'apple.com':
        return 'Apple';
      case 'facebook.com':
        return 'Facebook';
      default:
        return providerId;
    }
  }

  IconData _providerIcon(String providerId) {
    switch (providerId) {
      case 'password':
        return Icons.alternate_email;
      case 'google.com':
        return Icons.login;
      case 'apple.com':
        return Icons.apple;
      case 'facebook.com':
        return Icons.facebook;
      default:
        return Icons.link;
    }
  }

  // Brand block used on both mobile and wide layouts (no animations)
  Widget _brandBlock(
    BuildContext context, {
    double iconSize = 80,
    TextStyle? titleStyle,
    String? subtitle,
    TextStyle? subtitleStyle,
  }) {
    final theme = Theme.of(context);
    titleStyle ??= theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'app-logo',
          child: Icon(
            Icons.shopping_bag_outlined,
            size: iconSize,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Passage',
          style: (titleStyle ?? theme.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: (subtitleStyle ?? theme.textTheme.titleMedium)?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildForm(BuildContext context, BoxConstraints c) {
    final theme = Theme.of(context);

    final form = Form(
      key: _formKey,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Welcome Back!',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue shopping',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Unified login: no role toggle
              const SizedBox(height: 12),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() {
                      _obscurePassword = !_obscurePassword;
                    }),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  child: _isSubmitting
                      ? Row(
                          key: const ValueKey('progress'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation(
                                  theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Signing In...'),
                          ],
                        )
                      : const Text(
                          'Sign In',
                          key: ValueKey('label'),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isGoogleSubmitting ? null : _signInWithGoogle,
                icon: _isGoogleSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(_isGoogleSubmitting ? 'Connecting…' : 'Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.authFormMaxWidth(c)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Material(
            elevation: 8,
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: form,
            ),
          ),
        ),
      ),
    );
  }

  Widget _staticBackground(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F3FF), Color(0xFFE7F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _staticBackground(context),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final theme = Theme.of(context);
                final isWide = c.maxWidth >= AppBreakpoints.tablet;

                if (isWide) {
                  // Split layout for tablet/desktop
                  return Row(
                    children: [
                      if (c.maxWidth >= AppBreakpoints.desktop)
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEAE0FF), Color(0xFFD7F2FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: _brandBlock(
                                  context,
                                  iconSize: 96,
                                  titleStyle: theme.textTheme.displaySmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  subtitle: 'Discover your next favorite',
                                  subtitleStyle: theme.textTheme.titleMedium,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildForm(context, c),
                        ),
                      ),
                    ],
                  );
                }

                // Mobile: centered, constrained form
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _brandBlock(context),
                      _buildForm(context, c),
                    ],
                  ),
                );
              },
            ),
          ),
          // Removed: temporary footer label that displayed host and Firebase project
        ],
      ),
    );
  }
}