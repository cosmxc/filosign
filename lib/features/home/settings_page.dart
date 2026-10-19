  import 'dart:async';

  import 'package:supabase_flutter/supabase_flutter.dart';
  import 'package:flutter/material.dart';

  import '../auth/auth_page.dart' as auth;
  import '../auth/otp_verification_screen.dart';

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
            _buildAccountActionTile(
              icon: Icons.person_outline_rounded,
              title: 'Change username',
              subtitle: (Supabase.instance.client.auth.currentUser?.userMetadata?['display_name'] as String?) ?? '',
              onTap: _showChangeUsernameDialog,
            ),
            _buildAccountActionTile(
              icon: Icons.alternate_email_rounded,
              title: 'Change email',
              subtitle: Supabase.instance.client.auth.currentUser?.email ?? '',
              onTap: _showChangeEmailDialog,
            ),
            _buildAccountActionTile(
              icon: Icons.password_rounded,
              title: 'Change password',
              subtitle: 'Update your account password',
              onTap: _changePasswordOtpFlow
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Account'),
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

    Future<void> _showChangeUsernameDialog() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user  == null) return;

      final currentUsername = (user.userMetadata?['display_name'] as String?)?.trim() ?? '';
      final usernameController = TextEditingController(text: currentUsername);
      final formKey = GlobalKey<FormState>();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Change username'),
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: TextFormField(
              controller: usernameController,
              keyboardType: TextInputType.text,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'New username',
                counterText: '',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Enter a username';
                if (v.length < 2) return 'Username must be at least 2 characters';
                if (v.length > 30) return 'Username must be 30 characters or fewer';
                if (v == currentUsername) {
                  return 'New username must be different from current username';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final newUsername = usernameController.text.trim();
                Navigator.pop(dialogContext);

                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(data: {'display_name': newUsername}),
                  );

                  if (!context.mounted) return;
                  setState(() {});
                  _showMessage('Username updated successfully.');
                } on AuthException catch (e) {
                  _showMessage(_accountErrorMessage(e.code ?? ''), isError: true);
                } catch (_) {
                  _showMessage('Could not update username. Please try again.',
                      isError: true);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }

    Future<void> _showChangeEmailDialog() async {
      final emailController = TextEditingController();
      final formKey = GlobalKey<FormState>();
      final currentEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            scrollable: true,
            title: const Text('Change email'),
            content: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 256,
                    decoration: const InputDecoration(
                      labelText: 'New email address',
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter an email address';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      if (value.trim().toLowerCase() == currentEmail.toLowerCase()) {
                        return 'New email must be different from current email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  
                  final newEmail = emailController.text.trim();
                  Navigator.pop(dialogContext);

                  try {
                    await Supabase.instance.client.auth.updateUser(
                      UserAttributes(email: newEmail),
                    );

                    if (!context.mounted) return;
                    _showMessage('Verification links sent! Please check your email to confirm the change.');
                  } on AuthException catch (e) {
                    _showMessage(_accountErrorMessage(e.code ?? ''), isError: true);
                  } catch (_) {
                    _showMessage('Could not initiate email change setup.', isError: true);
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> _changePasswordOtpFlow() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final email = user.email!;   
      
      try {
        // 1. Request reauthentication OTP code to email
        await Supabase.instance.client.auth.reauthenticate();
        if (!mounted) return;
        
        // 2. Open OTP screen and WAIT for the 6-digit string to be returned via Navigator.pop
        final String? otpNonce = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: email,  
              action: 'reauthenticate',
            ),   
          ),
        );

        // 3. If the user successfully provided an OTP code, open the change password dialog
        if (otpNonce != null && mounted) {
          _showChangePasswordDialog(otpNonce);
        }
      } on AuthException catch (e) {
        _showMessage(_accountErrorMessage(e.code ?? ''), isError: true);    
      } catch (_) {
        _showMessage('Could not send OTP for password change.', isError: true); 
      }
    }

    Future<void> _showChangePasswordDialog(String otpNonce) async {
      final newPasswordController = TextEditingController();
      final confirmPasswordController = TextEditingController();
      final formKey = GlobalKey<FormState>();
      
      // Track password visibility state locally
      bool obscureNewPassword = true;
      bool obscureConfirmPassword = true;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            scrollable: true,
            title: const Text('Change password'),
            content: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setDialogState(() => obscureNewPassword = !obscureNewPassword),
                      ),
                      errorMaxLines: 3,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
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
                ],
              ),
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                // Ensure validation check runs safely on tap execution
                if (!formKey.currentState!.validate()) return;
                
                Navigator.pop(dialogContext);
                final currentUser = Supabase.instance.client.auth.currentUser;
                if (currentUser == null) return;

                try {
                  // Supply BOTH password and nonce parameters together!
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(
                      password: newPasswordController.text.trim(),
                      nonce: otpNonce, 
                    ),
                  );
                  _showMessage('Password updated successfully.');
                } on AuthException catch (e) {
                  _showMessage(_accountErrorMessage(e.code ?? ''), isError: true);
                } catch (_) {
                  _showMessage('An unexpected error occurred.', isError: true);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      )
    );
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
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => auth.AuthPage()));
      }
    }

    Future<void> _deleteAccount() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Show confirmation dialog
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to permanently delete your account? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (shouldDelete != true) return;

      // Send OTP for re-authentication
      await _sendOtpForReauthentication(user.email!);
    }

    Future<void> _sendOtpForReauthentication(String email) async {
      try {
        await Supabase.instance.client.auth.reauthenticate();
        if (!mounted) return;
        final String? otpNonce = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: email,
              action: 'reauthenticate',
            ),
          ),
        );
        if (otpNonce != null && mounted) {
          await _deleteAccountWithOtpVerified(otpNonce);
        }
      } on AuthException catch (e) {
        _showMessage(_accountErrorMessage(e.code ?? ''), isError: true);
      } catch (_) {
        _showMessage('Could not send OTP for account deletion.', isError: true);
      }
    }

    Future<void> _deleteAccountWithOtpVerified(String otpNonce) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      try {
        final res = await Supabase.instance.client.functions.invoke('delete-account');
        if (res.status != 200) throw Exception(res.data);
        
        await Supabase.instance.client.auth.signOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => auth.AuthPage()),
          (route) => false,
        );
        _showMessage('Account permanently deleted.');
      } on AuthException catch (e) {
        if (!mounted) return;
        _showMessage(_accountErrorMessage(e.code ?? ''), isError: true);
      } catch (e) {
        if (!mounted) return;
        _showMessage('Error deleting account: $e', isError: true);
      }
    }
  }