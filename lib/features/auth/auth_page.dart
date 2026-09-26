import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../home/home_page.dart';

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

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await credential.user?.updateDisplayName(_nameController.text.trim());
        await _auth.signOut();
        if (mounted) {
          setState(() => _isSignUp = false);
          _passwordController.clear();
          _showMessage('Account created. Please sign in.');
        }
      } else {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage(_messageFor(error.code), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage(
        'Enter your email first to reset your password.',
        isError: true,
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) _showMessage('Password reset email sent.');
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage(_messageFor(error.code), isError: true);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB42318)
              : const Color(0xFF087F73),
        ),
      );
  }

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
                  child: isWide ? _buildWideLayout() : _buildCompactLayout(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return SizedBox(
      height: 650,
      child: Row(
        children: [
          Expanded(child: _buildWelcomePanel()),
          const SizedBox(width: 34),
          Expanded(child: _buildFormCard()),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        _buildBrandHeader(),
        const SizedBox(height: 28),
        _buildFormCard(),
      ],
    );
  }

  Widget _buildWelcomePanel() {
    return Container(
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF087F73), Color(0xFF10A99A), Color(0xFFF18A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29108075),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBrandHeader(light: true),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp
                    ? 'Learn Filipino Sign Language\nwith Filosign.'
                    : 'Continue your\nFSL journey.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isSignUp
                    ? 'Build confidence through lessons, practice,\nand everyday Filipino Sign Language.'
                    : 'Pick up where you left off and keep\nlearning Filipino Sign Language.',
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.white, size: 19),
              SizedBox(width: 9),
              Text(
                'Learn. Practice. Connect.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader({bool light = false}) {
    final foreground = light ? Colors.white : const Color(0xFF087F73);
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
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandHeader(),
            const SizedBox(height: 30),
            Text(
              _isSignUp ? 'Create your account' : 'Welcome back',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF153B39),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _isSignUp
                  ? 'Start learning FSL today.'
                  : 'Sign in to continue your lessons.',
              style: const TextStyle(color: Color(0xFF64807C), fontSize: 14),
            ),
            const SizedBox(height: 26),
            if (_isSignUp) ...[
              _buildField(
                controller: _nameController,
                label: 'Full name',
                icon: Icons.person_outline_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your name';
                  }
                  if (value.trim().length > 30) {
                    return 'Name must be 30 characters or fewer';
                  }
                  return null;
                },
                hideCounter: true,
              ),
              const SizedBox(height: 14),
            ],
            _buildField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: _isSignUp
                  ? passwordValidationMessage
                  : (value) => value == null || value.trim().isEmpty
                      ? 'Enter your password'
                      : null,
            ),
            if (!_isSignUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF087F73),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSignUp ? 'Create account' : 'Sign in',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFD7E5E2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(color: Color(0xFF8BA09D), fontSize: 12),
                  ),
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
                    _isSignUp
                        ? 'Already have an account? '
                        : 'New to Filosign? ',
                    style: const TextStyle(
                      color: Color(0xFF64807C),
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Sign in' : 'Create one',
                      style: const TextStyle(
                        color: Color(0xFFF07932),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    bool hideCounter = false,
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
}
