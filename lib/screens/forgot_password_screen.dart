import 'package:flutter/material.dart';
import 'package:passage/screens/login_screen.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/utils/responsive.dart';
import 'package:passage/widgets/auth_branding.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _emailKey = GlobalKey<FormState>();
  late final AnimationController _introController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _formSlide;
  bool _sending = false;
  bool _sent = false;
  String? _sentTo;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _introController, curve: const Interval(0.2, 1, curve: Curves.easeOut)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _introController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_emailKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _sending = true);
    try {
      await FirebaseAuthService.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sentTo = email;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _formCard(BuildContext context, BoxConstraints c, Widget child) {
    final theme = Theme.of(context);
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
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(BuildContext context, BoxConstraints c) {
    final theme = Theme.of(context);
    return Form(
      key: _emailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Forgot Password',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the email associated with your account. We\'ll email you a secure reset link.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _sending ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _sending
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _buildSentStep(BuildContext context, BoxConstraints c) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'Check your inbox',
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _sentTo != null
              ? 'We\'ve sent a password reset link to $_sentTo.'
              : 'We\'ve sent a password reset link to your email.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pageContent = LayoutBuilder(
      builder: (context, c) {
        final inner = FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _formSlide,
            child: _formCard(
              context,
              c,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _sent ? _buildSentStep(context, c) : _buildEmailStep(context, c),
              ),
            ),
          ),
        );

        final isWide = c.maxWidth >= AppBreakpoints.tablet;
        if (isWide) {
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
                        child: AuthBrandHeader(
                          iconSize: 96,
                          titleStyle: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                          subtitle: 'Secure Reset',
                          subtitleStyle: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(child: SingleChildScrollView(child: inner)),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const AuthBrandHeader(),
              inner,
            ],
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthAnimatedBackground(),
          SafeArea(child: pageContent),
        ],
      ),
    );
  }
}
