import 'dart:math';

import 'package:flutter/material.dart';
import 'package:passage/seller/seller_login_screen.dart';
import 'package:passage/services/local_seller_accounts_store.dart';

class SellerForgotPasswordScreen extends StatefulWidget {
  const SellerForgotPasswordScreen({super.key});

  @override
  State<SellerForgotPasswordScreen> createState() => _SellerForgotPasswordScreenState();
}

class _SellerForgotPasswordScreenState extends State<SellerForgotPasswordScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  final _emailKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  int _step = 0; // 0 email, 1 code, 2 reset
  String? _targetEmail; // normalized
  String? _issuedCode;
  DateTime? _expiresAt;
  bool _sending = false;

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
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  String _generateCode() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  Future<void> _sendCode() async {
    if (!_emailKey.currentState!.validate()) return;

    final inputEmail = _emailCtrl.text.trim().toLowerCase();
    setState(() => _sending = true);
    final exists = await LocalSellerAccountsStore.emailExists(inputEmail);

    if (!mounted) return;
    if (!exists) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller email not found')),
      );
      return;
    }

    final code = _generateCode();
    final expiry = DateTime.now().add(const Duration(minutes: 10));

    setState(() {
      _issuedCode = code;
      _expiresAt = expiry;
      _targetEmail = inputEmail;
      _step = 1;
      _sending = false;
    });

    // Note: In a real app you would send this code by email. For demo we show the code on screen.
  }

  void _verifyCode() {
    if (!_codeKey.currentState!.validate()) return;
    final entered = _codeCtrl.text.trim();
    if (_issuedCode == null || _expiresAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please request a new code')),
      );
      return;
    }

    if (DateTime.now().isAfter(_expiresAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code expired. Request a new one.')),
      );
      return;
    }

    if (entered != _issuedCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid code')),
      );
      return;
    }

    setState(() => _step = 2);
  }

  Future<void> _resetPassword() async {
    if (!_resetKey.currentState!.validate()) return;

    final email = _targetEmail;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing email. Restart reset process.')),
      );
      return;
    }

    final ok = await LocalSellerAccountsStore.updatePassword(email: email, newPassword: _pwCtrl.text);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reset password. Try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset. Please sign in.')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SellerLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Password Reset'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: () {
                        switch (_step) {
                          case 0:
                            return Form(
                              key: _emailKey,
                              child: Column(
                                key: const ValueKey('emailStep'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.teal.withValues(alpha: 0.12),
                                        child: const Icon(Icons.sell_outlined, color: Colors.teal),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('Forgot password', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Seller email',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Enter your seller email';
                                      if (!v.contains('@')) return 'Enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: _sending ? null : _sendCode,
                                    child: _sending
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('Send code'),
                                  ),
                                ],
                              ),
                            );
                          case 1:
                            final remaining = _expiresAt != null ? _expiresAt!.difference(DateTime.now()) : const Duration(seconds: 0);
                            final minutes = remaining.inMinutes.clamp(0, 59);
                            final seconds = (remaining.inSeconds % 60).clamp(0, 59);
                            return Form(
                              key: _codeKey,
                              child: Column(
                                key: const ValueKey('codeStep'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Verify code', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 12),
                                  if (_issuedCode != null)
                                    Text('Demo code: $_issuedCode', textAlign: TextAlign.left, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                                  const SizedBox(height: 8),
                                  Text('Code expires in ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}', style: theme.textTheme.bodySmall),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _codeCtrl,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: const InputDecoration(
                                      labelText: '6-digit code',
                                      prefixIcon: Icon(Icons.verified_outlined),
                                      counterText: '',
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Enter the code';
                                      if (v.length != 6 || int.tryParse(v) == null) return 'Enter a valid 6-digit code';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(onPressed: _verifyCode, child: const Text('Verify')),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _issuedCode = _generateCode();
                                        _expiresAt = DateTime.now().add(const Duration(minutes: 10));
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code has been generated.')));
                                    },
                                    child: const Text('Resend code'),
                                  ),
                                ],
                              ),
                            );
                          case 2:
                          default:
                            return Form(
                              key: _resetKey,
                              child: Column(
                                key: const ValueKey('resetStep'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Set a new password', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _pwCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'New password',
                                      prefixIcon: Icon(Icons.lock_reset_outlined),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Enter a new password';
                                      if (v.length < 8) return 'At least 8 characters';
                                      if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add an uppercase letter';
                                      if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add a number';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _pwConfirmCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm new password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Confirm your password';
                                      if (v != _pwCtrl.text) return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(onPressed: _resetPassword, child: const Text('Reset password')),
                                ],
                              ),
                            );
                        }
                      }(),
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
