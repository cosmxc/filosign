import 'package:filosign/features/auth/legal_document_modal.dart';
import 'package:filosign/features/auth/otp_verification_screen.dart';
import 'package:filosign/features/home/home_page.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthAction { signUp, signInWithPassword, signInWithCode }


//Messages Password
String? passwordValidationMessage(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Enter a password.';
  }

  if (value.length < 8) {
    return 'Password must be at least 8 characters long.';
  }

  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Password must include 1 special character.';
  }

  if (!RegExp(r'\d').hasMatch(value)) {
    return 'Password must include 1 number.';
  }

  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must include 1 capital letter.';
  }

  return null;
}

//Messages Sign-in-sign-up
String _authErrorMessage(String? message) {
  if (message == null) return 'Something went wrong. Please try again.';
  final lower = message.toLowerCase();
  if (lower.contains('invalid email') || lower.contains('invalid-credential')) {
    return 'Enter a valid email address.';
  }
  if (lower.contains('wrong-password') || lower.contains('invalid-credential') || lower.contains('user-not-found')) {
    return 'The email or password is incorrect.';
  }
  if (lower.contains('weak-password')) {
    return 'Choose a stronger password with at least 6 characters.';
  }
  if (lower.contains('too-many-requests') || lower.contains('rate limit') || lower.contains('8 seconds')) {
    return 'Security cooldown: Please wait 8 seconds before trying again.';
  }
  if (lower.contains('email not verified') || lower.contains('email_confirmation_required')) {
    return 'Please verify your email before signing in.';
  }
  return message;
}


class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthAction _action = AuthAction.signInWithPassword;
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Lockout state
  bool _isLockedOut = false;
  int _failedAttempts = 0;
  DateTime? _lockUntil;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLockoutState();
  }

  Future<void> _loadLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLockedOut = prefs.getBool('is_locked_out') ?? false;
      _failedAttempts = prefs.getInt('failed_attempts') ?? 0;
      final expiresStr = prefs.getString('lock_until');
      _lockUntil = expiresStr != null ? DateTime.parse(expiresStr) : null;
      _checkLockout();
    });
  }

  void _checkLockout() {
    if (_isLockedOut && _lockUntil != null && DateTime.now().isAfter(_lockUntil!)) {
      _isLockedOut = false;
      _failedAttempts = 0;
      _saveLockoutState();
    }
  }

  Future<void> _saveLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_locked_out', _isLockedOut);
    await prefs.setInt('failed_attempts', _failedAttempts);
    if (_lockUntil != null) {
      await prefs.setString('lock_until', _lockUntil!.toIso8601String());
    } else {
      await prefs.remove('lock_until');
    }
  }

// Execute sign up
  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );

      final userIdentities = response.user?.identities;
      final emailIsTaken = userIdentities != null && userIdentities.isEmpty;

      if (emailIsTaken) {
        await _signInWithCode();
        return;
      }
      if (!mounted) return;

      //fake sucess for existing emails, to prevent email leaks
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A verification code has been sent to your email.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            action: 'signup',
          ),
        ),
      );
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('already registered') || lower.contains('user already exists') || lower.contains('supplied email')) {
        await _signInWithCode();
        if (!mounted) return;

      } else {
        _showError(_authErrorMessage(e.message));
      }
    } catch (e) {
      if (!mounted) return;
      _showError('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

//Password sign in
  Future<void> _signInWithPassword() async {
    _checkLockout();
    if (_isLockedOut) {
      _showError('Account locked out. Try again in 15 minutes.');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Sign in with password
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Reset failed attempts on success
      _failedAttempts = 0;
      _saveLockoutState();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      // Increment failed attempts
      _failedAttempts++;
      _saveLockoutState();

      // Check if locked out after 5 failures
      if (_failedAttempts >= 5) {
        _isLockedOut = true;
        _lockUntil = DateTime.now().add(const Duration(minutes: 15));
        _saveLockoutState();
      }

      if (!mounted) return;
      _showError(_authErrorMessage(e.message));
    } catch (e) {
      if (!mounted) return;
      _showError('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

//Sign in with Code
  Future<void> _signInWithCode() async {
    _checkLockout();
    if (_isLockedOut) {
      _showError('Account locked out. Try again in 15 minutes.');
      return;
    }

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Send OTP for sign in with code
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );

      // Reset failed attempts on success
      _failedAttempts = 0;
      _saveLockoutState();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            action: 'signin_with_code',
          ),
        ),
      );
    } on AuthException catch (e) {
      // Increment failed attempts
      _failedAttempts++;
      _saveLockoutState();

      // Check if locked out after 5 failures
      if (_failedAttempts >= 5) {
        _isLockedOut = true;
        _lockUntil = DateTime.now().add(const Duration(minutes: 15));
        _saveLockoutState();
      }

      if (!mounted) return;
      _showError('An error occurred.');
    } catch (e) {
      if (!mounted) return;
      _showError('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// Execute forgot password
  Future<void> _forgotPassword() async {
      _checkLockout();
       if (_isLockedOut) {
        _showError('Account locked out. Try again in 15 minutes.');
        return;
      }
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            action: 'forgot_password',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError('An error occurred.');
    } catch (_) {
      if (!mounted) return;
      _showError('An error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool get _primaryButtonDisabled {
    if (_isSignUp) return !_acceptedTerms || !_acceptedPrivacy;
    return _isLockedOut;
  }

Future<void> _openTerms() async {
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: LegalDocumentModal(
          title: 'Terms and Conditions',
          assetPath: 'assets/html/terms.html',
          onAgreed: () {
            if (mounted) setState(() => _acceptedTerms = true);
          },
        ),
      ),
    ),
  );
}

Future<void> _openPrivacy() async {
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: LegalDocumentModal(
          title: 'Privacy Policy',
          assetPath: 'assets/html/policy.html',
          onAgreed: () {
            if (mounted) setState(() => _acceptedPrivacy = true);
          },
        ),
      ),
    ),
  );
}

  Widget _buildBrandHeader({bool light = false}) {
    final foreground = light ? Colors.white : Color(0xFF087F73);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sign_language, color: foreground, size: 30),
        const SizedBox(width: 10),
        Text(
          'Filosign',
          style: TextStyle(
            color: foreground,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    int? maxLength,
    bool hideCounter = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        counterText: hideCounter ? '' : null,
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5FAF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFE3EFEC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFE06A5F)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        errorMaxLines: 3,
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18087F73),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandHeader(),
            const SizedBox(height: 30),
            Text(
              _isSignUp ? 'Create your account' : 'Welcome back',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF153B39),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _isSignUp
                  ? ' Start learning FSL today.'
                  : ' Sign in to continue your lessons.',
              style: TextStyle(color: Color(0xFF64807C), fontSize: 14),
            ),
            const SizedBox(height: 26),

            // Name field (sign up only)
            if (_isSignUp) ...[
              _buildField(
                controller: _nameController,
                label: 'Username',
                icon: Icons.person_outline_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter your username';
                  if (value.trim().length > 30) return 'Username must be 30 characters or fewer';
                  return null;
                },
                maxLength: 30,
              ),
              const SizedBox(height: 14),
            ],

            // Email field
            _buildField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) =>
                  value == null || !value.contains('@') ? 'Enter a valid email' : null,
              maxLength: 256,
            ),
            const SizedBox(height: 14),

            // Password field
            _buildField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffix: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
              validator: passwordValidationMessage,
              maxLength: 30,
            ),
            if (!_isSignUp) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: (_isLoading || _isLockedOut) ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            ],

            if (_isSignUp) ...[
              const SizedBox(height: 14),

              // Terms and Conditions acceptance row
              Row(
                children: [
                 Checkbox(
                  value: _acceptedTerms,
                  onChanged: null, 
                  fillColor: WidgetStateProperty.resolveWith((_) {
                    return _acceptedTerms
                        ? const Color(0xFF087F73)   
                        : Colors.transparent;       
                  }),
                  checkColor: const Color(0xFFFFFFFF),
                  side: BorderSide(
                    color: _acceptedTerms
                        ? const Color(0xFF087F73)
                        : const Color(0xFFB7C9C6),   
                    width: 1.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                  Expanded(
                    child: Wrap(
                      children: [
                        Text(
                          'I have read and agree to the ',
                          style: TextStyle(color: Color(0xFF64807C), fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: _openTerms,
                          child: Text(
                            'Terms and Conditions',
                            style: TextStyle(
                              color: Color(0xFF087F73),
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Privacy Policy acceptance row
              Row(
                children: [
                 Checkbox(
                    value: _acceptedPrivacy,
                    onChanged: null, // ← never user-editable, ever
                    fillColor: WidgetStateProperty.resolveWith((_) {
                      return _acceptedPrivacy
                          ? const Color(0xFF087F73)   // teal when agreed
                          : Colors.transparent;        // empty otherwise
                    }),
                    checkColor: const Color(0xFFFFFFFF),
                    side: BorderSide(
                      color: _acceptedTerms
                          ? const Color(0xFF087F73)
                          : const Color(0xFFB7C9C6),   // muted gray outline when not agreed
                      width: 1.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [
                        Text(
                          'I have read and agree to the ',
                          style: TextStyle(color: Color(0xFF64807C), fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: _openPrivacy,
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Color(0xFF087F73),
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Primary action button - greyed out only when relevant to the
            // current screen (sign-up: checkboxes, sign-in: lockout).
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: (_isLoading || _primaryButtonDisabled)
                    ? null
                    : (_isSignUp
                        ? _signUp
                        : _action == AuthAction.signInWithPassword
                            ? _signInWithPassword
                            : _signInWithCode),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryButtonDisabled
                      ? Colors.grey
                      : const Color(0xFF087F73),
                  foregroundColor: _primaryButtonDisabled
                      ? Colors.white70
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isSignUp
                            ? 'Create account'
                            : _action == AuthAction.signInWithPassword
                                ? 'Sign in'
                                : 'Sign in OTP',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Alternative sign-in options - show based on action
            if (!_isSignUp) ...[
              if (_action == AuthAction.signInWithPassword)
                Center(
                  child: TextButton(
                    onPressed: _isLoading || _isLockedOut ? null : _signInWithCode,
                    child: const Text('Sign in with email code instead'),
                  ),
                ),
              if (_action == AuthAction.signInWithCode)
                Center(
                  child: TextButton(
                    onPressed: _isLoading || _isLockedOut ? null : _signInWithPassword,
                    child: const Text('Sign in with password'),
                  ),
                ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFD7E5E2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: Color(0xFF8BA09D), fontSize: 12)),
                ),
                const Expanded(child: Divider(color: Color(0xFFD7E5E2))),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    _isSignUp ? 'Already have an account? ' : 'New to Filosign? ',
                    style: TextStyle(color: Color(0xFF64807C), fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _action = AuthAction.signInWithPassword;
                              _acceptedTerms = false;
                              _acceptedPrivacy = false;
                              _passwordController.clear();
                              _emailController.clear();
                              _nameController.clear();
                            }),
                    child: Text(
                      _isSignUp ? 'Sign in' : 'Create one',
                      style: TextStyle(color: Color(0xFFF07932), fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FFFD), Color(0xFFE6F8F4), Color(0xFFFFF4E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 56 : 22,
                  vertical: isWide ? 44 : 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: _buildFormCard(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}