import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';
import 'otp_screen.dart';

/// ============================================================
/// LoginScreen — Phone OTP + Email login (Supabase Auth)
/// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController(text: '+92');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPhoneMode = true;
  bool _isRegister = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() {
    final authService = context.read<AuthService>();
    final phone = _phoneController.text.trim();

    if (phone.length < 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Pakistani phone number (+92XXXXXXXXXX)')),
      );
      return;
    }

    authService.sendOtp(
      phoneNumber: phone,
      onCodeSent: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phone)),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      },
    );
  }

  Future<void> _emailAction() async {
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email and password (6+ chars)')),
      );
      return;
    }

    final user = _isRegister
        ? await authService.registerWithEmail(email, password)
        : await authService.signInWithEmail(email, password);

    if (user != null && _isRegister) {
      // Create user profile row in Supabase on registration
      await dbService.createUser(UserModel(
        id: user.id,
        name: user.email?.split('@').first ?? 'Runner',
        email: user.email,
        createdAt: DateTime.now(),
      ));
    }

    if (authService.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authService.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF0F3460)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // ── Logo & Title ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FortRunTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: FortRunTheme.primaryGreen.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_run_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'FORTRUN',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اسلام آباد کی سڑکیں آپ کا قلعہ',
                    style: TextStyle(
                      fontSize: 14,
                      color: FortRunTheme.primaryGreen.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Defend Your Territory. Sabotage Your Rivals.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // ── Mode Toggle ──────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: FortRunTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPhoneMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _isPhoneMode
                                    ? FortRunTheme.primaryGreen
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '📱 Phone OTP',
                                  style: TextStyle(
                                    color: _isPhoneMode
                                        ? Colors.white
                                        : FortRunTheme.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPhoneMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: !_isPhoneMode
                                    ? FortRunTheme.primaryGreen
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '✉️ Email',
                                  style: TextStyle(
                                    color: !_isPhoneMode
                                        ? Colors.white
                                        : FortRunTheme.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── Input Fields ─────────────────────────
                  if (_isPhoneMode) ...[
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_android),
                        hintText: '+92 3XX XXXXXXX',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authService.isLoading ? null : _sendOtp,
                        child: authService.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('SEND OTP'),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'Email address',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Password (6+ characters)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authService.isLoading ? null : _emailAction,
                        child: authService.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(_isRegister ? 'REGISTER' : 'SIGN IN'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister
                            ? 'Already have an account? Sign In'
                            : 'New here? Create Account',
                        style: TextStyle(
                          color: FortRunTheme.primaryGreen.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  Text(
                    '🇵🇰 Made for runners in Islamabad',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
