import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return _buildSecondaryPage(
      icon: Icons.settings_rounded,
      title: 'Settings',
      child: Column(
        children: [
          _buildSettingTile(
            Icons.notifications_none_rounded,
            'Notifications',
            'Daily learning reminders',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) => setState(() => _notificationsEnabled = value),
            ),
          ),
          _buildSettingTile(
            Icons.language_rounded,
            'Learning language',
            'Filipino Sign Language',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF6B8581),
            ),
          ),
          _buildSettingTile(
            Icons.help_outline_rounded,
            'Help and feedback',
            'Get support or share feedback',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF6B8581),
            ),
          ),
          _buildAccountActionTile(
            icon: Icons.alternate_email_rounded,
            title: 'Change email',
            subtitle: FirebaseAuth.instance.currentUser?.email ?? '',
            onTap: _showChangeEmailDialog,
          ),
          _buildAccountActionTile(
            icon: Icons.password_rounded,
            title: 'Change password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
                side: const BorderSide(color: Color(0xFFF0B8B2), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryPage({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF087F73), size: 27),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF153B39),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title,
    String subtitle, {
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEEB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF087F73)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF153B39),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B8581),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildAccountActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEEB)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(icon, color: const Color(0xFF087F73)),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF153B39),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6B8581), fontSize: 12),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF6B8581),
          ),
        ),
      ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    final emailController = TextEditingController();
    final currentPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isLoading = false;
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Change email'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'New email address',
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    if (value.trim() == currentEmail) {
                      return 'New email must be different from current email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Enter your current password'
                          : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      var success = false;
                      try {
                        success = await _changeEmail(
                          emailController.text.trim(),
                          currentPasswordController.text,
                        ).timeout(const Duration(seconds: 15));
                      } on TimeoutException {
                        _showMessage(
                          'The request timed out. Please try again.',
                          isError: true,
                        );
                      } catch (_) {
                        _showMessage(
                          'Could not change your email. Please try again.',
                          isError: true,
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isLoading = false);
                          if (success) Navigator.pop(dialogContext);
                        }
                        if (success && mounted) {
                          _showMessage('Verification email sent.');
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    emailController.dispose();
    currentPasswordController.dispose();
  }

Future<void> _showChangePasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final currentPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool obscureCurrent = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                    errorMaxLines: 3,
                  ),
                  validator: (value) {
                    final msg = passwordValidationMessage(value);
                    if (msg != null) return msg;
                    if (value == currentPasswordController.text) {
                      return 'New password must be different from current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm),
                    ),
                    errorMaxLines: 3,
                  ),
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                          () => obscureCurrent = !obscureCurrent),
                    ),
                    errorMaxLines: 3,
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Enter your current password'
                          : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      var success = false;
                      try {
                        success = await _changePassword(
                          newPasswordController.text,
                          currentPasswordController.text,
                        ).timeout(const Duration(seconds: 15));
                      } on TimeoutException {
                        _showMessage(
                          'The request timed out. Please try again.',
                          isError: true,
                        );
                      } catch (_) {
                        _showMessage(
                          'Could not change your password. Please try again.',
                          isError: true,
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isLoading = false);
                          if (success) Navigator.pop(dialogContext);
                        }
                        if (success && mounted) {
                          _showMessage('Password updated successfully.');
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    currentPasswordController.dispose();
  }

  Future<bool> _reauthenticate(String currentPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      _showMessage('Unable to find the current account.', isError: true);
      return false;
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    return true;
  }

  Future<bool> _changeEmail(String email, String currentPassword) async {
    try {
      if (await _reauthenticate(currentPassword)) {
        await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(email);
        return true;
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_accountErrorMessage(error.code), isError: true);
    }
    return false;
  }

  Future<bool> _changePassword(
    String newPassword,
    String currentPassword,
  ) async {
    try {
      if (await _reauthenticate(currentPassword)) {
        await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
        return true;
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_accountErrorMessage(error.code), isError: true);
    }
    return false;
  }

  String _accountErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Your current password is incorrect.';
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your account details.';
      default:
        return 'Could not update your account details. Please try again.';
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
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

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
    }
  }
}