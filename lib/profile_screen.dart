import 'package:flutter/material.dart';

import 'api_client.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _primaryBlue = Color(0xFF2A3EDB);
  static const _darkNavy = Color(0xFF13205C);

  Future<void> _handleLogout() async {
    await ApiClient.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleChangePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() {
                submitting = true;
                error = null;
              });
              try {
                await ApiClient.changePassword(
                  oldPassword: oldController.text,
                  newPassword: newController.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully.')),
                );
              } on ApiException catch (e) {
                setDialogState(() {
                  error = e.message;
                  submitting = false;
                });
              } catch (_) {
                setDialogState(() {
                  error = 'Could not change password. Please try again.';
                  submitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null) ...[
                      Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      controller: oldController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Current password'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New password'),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Must be at least 6 characters'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: _darkNavy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: _primaryBlue,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.username, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('View & edit profile', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: _darkNavy),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _handleChangePassword,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
