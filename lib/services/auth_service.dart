import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================
/// AuthService — Supabase Authentication
///
/// Supports:
///   • Email/Password (sign in & register)
///   • Phone OTP (send code → verify code)
///   • Auth state change listener (auto-triggers UI rebuild)
///
/// Production notes:
///   • Phone OTP requires an SMS provider (Twilio/Vonage/MessageBird)
///     configured in Supabase Dashboard → Authentication → Phone Provider.
///   • Row-Level Security (RLS) policies in the database use
///     auth.uid() to restrict data access per user.
/// ============================================================

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authSubscription;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Current authenticated user (null if logged out).
  User? get currentUser => _client.auth.currentUser;

  /// Whether a user session exists.
  bool get isLoggedIn => _client.auth.currentSession != null;

  /// Current user's UUID (convenience getter).
  String? get uid => currentUser?.id;

  AuthService() {
    // Listen to auth state changes (login, logout, token refresh)
    _authSubscription = _client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // ── Phone OTP Login ────────────────────────────────────────

  /// Step 1: Send OTP to phone number (format: +92XXXXXXXXXX)
  Future<void> sendOtp({
    required String phoneNumber,
    required VoidCallback onCodeSent,
    required Function(String error) onError,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.signInWithOtp(phone: phoneNumber);
      _isLoading = false;
      notifyListeners();
      onCodeSent();
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      onError(e.message);
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      onError(_errorMessage!);
    }
  }

  /// Step 2: Verify OTP code
  Future<User?> verifyOtp(String smsCode, {required String phone}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: smsCode,
      );
      _isLoading = false;
      notifyListeners();
      return response.user;
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  // ── Email/Password Login ───────────────────────────────────

  Future<User?> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return response.user;
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<User?> registerWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return response.user;
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  // ── Google OAuth Login (opens browser, no API key needed) ───

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.fortrun://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // Auth state listener handles the login completion
      _isLoading = false;
      notifyListeners();
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ── Sign Out ───────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
    notifyListeners();
  }
}
