import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';
import 'otp_screen.dart';

/// ============================================================
/// LoginScreen — Professional auth UI
/// Primary: Email / Password
/// Secondary: Google OAuth (needs Supabase config — see README)
/// Legacy: Phone OTP (requires paid SMS provider)
/// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController(text: '+92');
  bool _isRegister = false;
  bool _showPassword = false;
  bool _showPhone = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _emailAction() async {
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      _showError('Enter a valid email and password (6+ characters)');
      return;
    }

    final user = _isRegister
        ? await authService.registerWithEmail(email, password)
        : await authService.signInWithEmail(email, password);

    if (user != null && mounted) {
      // Always ensure a profile row exists (handles sign-up AND returning sign-in)
      final existing = await dbService.getUser(user.id);
      if (existing == null) {
        await dbService.createUser(UserModel(
          id: user.id,
          name: user.email?.split('@').first ?? 'Runner',
          email: user.email,
          createdAt: DateTime.now(),
        ));
      }
    }

    if (authService.errorMessage != null && mounted) {
      _showError(authService.errorMessage!);
    }
  }

  void _googleSignIn() async {
    final authService = context.read<AuthService>();
    await authService.signInWithGoogle();
    if (authService.errorMessage != null && mounted) {
      _showError(authService.errorMessage!);
    }
  }

  void _sendOtp() {
    final authService = context.read<AuthService>();
    final phone = _phoneController.text.trim();
    if (phone.length < 13) {
      _showError('Enter a valid Pakistani phone number (+92XXXXXXXXXX)');
      return;
    }
    authService.sendOtp(
      phoneNumber: phone,
      onCodeSent: () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phone)),
          );
        }
      },
      onError: _showError,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FortRunTheme.enemyRed.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: Stack(
        children: [
          // ── Background Gradient ──────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: FortRunTheme.backgroundGradient),
          ),

          // ── Green glow orb top-right ──────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FortRunTheme.primaryGreen.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: size.height * 0.04,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // ── Logo Row ─────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: FortRunTheme.primaryGradient,
                            ),
                            child: const Icon(Icons.directions_run_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'FORTRUN',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // ── Headline ─────────────────────────
                      Text(
                        _isRegister ? 'Create your\naccount' : 'Welcome\nback',
                        style: GoogleFonts.outfit(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Claim Islamabad. Defend your territory.',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: FortRunTheme.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Google Sign-In Button ─────────────
                      _GoogleButton(
                        isLoading: authService.isLoading,
                        onTap: _googleSignIn,
                      ),

                      const SizedBox(height: 20),

                      // ── Divider ───────────────────────────
                      Row(
                        children: [
                          const Expanded(child: Divider(color: FortRunTheme.cardDarkBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with email',
                              style: GoogleFonts.outfit(
                                color: FortRunTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: FortRunTheme.cardDarkBorder)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Email Field ───────────────────────
                      _buildLabel('Email address'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'your@email.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Password Field ────────────────────
                      _buildLabel('Password'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '6+ characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: FortRunTheme.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Primary Action ────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: authService.isLoading ? null : _emailAction,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: authService.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _isRegister ? 'Create Account' : 'Sign In',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Toggle register/login ─────────────
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _isRegister = !_isRegister),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: FortRunTheme.textMuted,
                              ),
                              children: [
                                TextSpan(
                                  text: _isRegister
                                      ? 'Already have an account? '
                                      : "Don't have an account? ",
                                ),
                                TextSpan(
                                  text: _isRegister ? 'Sign In' : 'Register',
                                  style: const TextStyle(
                                    color: FortRunTheme.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Phone OTP (collapsed by default) ──
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _showPhone = !_showPhone),
                          child: Text(
                            _showPhone ? 'Hide phone login' : 'Sign in with phone instead',
                            style: GoogleFonts.outfit(
                              color: FortRunTheme.textMuted,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: FortRunTheme.textMuted,
                            ),
                          ),
                        ),
                      ),

                      if (_showPhone) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.phone_android_outlined),
                            hintText: '+92 3XX XXXXXXX',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: authService.isLoading ? null : _sendOtp,
                            child: const Text('Send OTP'),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      // ── Footer ────────────────────────────
                      Center(
                        child: Text(
                          '🇵🇰  Built for runners in Pakistan',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: FortRunTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13,
        color: FortRunTheme.textSecondary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Google Sign-In Button ─────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _GoogleButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: FortRunTheme.cardDarkAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FortRunTheme.cardDarkBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G icon (colored circles)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
