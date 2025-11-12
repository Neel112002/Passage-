import 'package:flutter/material.dart';
import 'package:passage/services/local_seller_accounts_store.dart';
import 'package:passage/seller/seller_dashboard_screen.dart';

class SellerSignupScreen extends StatefulWidget {
  const SellerSignupScreen({super.key});

  @override
  State<SellerSignupScreen> createState() => _SellerSignupScreenState();
}

class _SellerSignupScreenState extends State<SellerSignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _storeName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscure2 = true;
  bool _submitting = false;

  late final AnimationController _intro;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _fadeIn = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _storeName.dispose();
    _password.dispose();
    _confirm.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final email = _email.text.trim();
    final name = _name.text.trim();
    final store = _storeName.text.trim().isEmpty ? null : _storeName.text.trim();
    final pw = _password.text;

    try {
      final exists = await LocalSellerAccountsStore.emailExists(email);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller with this email already exists')));
        }
        return;
      }

      final ok = await LocalSellerAccountsStore.addSeller(email: email, name: name, password: pw, storeName: store);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to create seller account')));
        }
        return;
      }

      await LocalSellerAccountsStore.setCurrentSeller(email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller account created')));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SellerDashboardScreen()),
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
      appBar: AppBar(title: const Text('Become a Seller')),
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
                    child: Form(
                      key: _formKey,
                      child: Column(
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
                              Text('Sign up to sell', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Your name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your name';
                              if (v.trim().length < 2) return 'Too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _storeName,
                            decoration: const InputDecoration(
                              labelText: 'Store name (optional)',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
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
                              if (v.length < 8) return 'At least 8 characters';
                              if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add an uppercase letter';
                              if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add a number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscure2,
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure2 = !_obscure2),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Confirm password';
                              if (v != _password.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _signup,
                            icon: _submitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1),
                            label: Text(_submitting ? 'Creating account...' : 'Create seller account'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                            child: const Text('Back'),
                          ),
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
