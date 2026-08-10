import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() => _errorMessage = 'Username or password is incorrect.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = error.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF12151E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF262C40) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.dynamicBackgroundGradient(context),
        ),
        child: Stack(
          children: [
            // Background glow orbs
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -60,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                ),
              ),
            ),
            // Scrollable content, fully centered
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 440,
                          minWidth: size.width < 440 ? size.width - 48 : 440,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Logo
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: 30,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Title
                            Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue chatting',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 36),
                            // Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_errorMessage != null) ...[
                                      ErrorBanner(message: _errorMessage!),
                                      const SizedBox(height: 16),
                                    ],
                                    DarkField(
                                      controller: _usernameController,
                                      label: 'Username',
                                      icon: Icons.person_outline_rounded,
                                      action: TextInputAction.next,
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                              ? 'Enter your username'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),
                                    DarkField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      action: TextInputAction.done,
                                      obscure: _obscurePassword,
                                      onToggleObscure: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      onSubmitted: (_) => _handleLogin(),
                                      validator: (v) =>
                                          v == null || v.isEmpty
                                              ? 'Enter your password'
                                              : null,
                                    ),
                                    const SizedBox(height: 24),
                                    GradientButton(
                                      label: 'Sign In',
                                      isLoading: _isLoading,
                                      onPressed: _handleLogin,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'No account yet? ',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/register'),
                                  child: const Text(
                                    'Create one',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
