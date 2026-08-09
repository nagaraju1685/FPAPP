import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? welcomeMessage;

  const LoginScreen({super.key, this.welcomeMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _primaryBlue = Color(0xFF2A3EDB);
  static const _fieldFill = Color(0xFFE8ECFB);

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  late final TapGestureRecognizer _createAccountRecognizer;

  @override
  void initState() {
    super.initState();
    _createAccountRecognizer = TapGestureRecognizer()..onTap = _handleCreateAccount;
    if (widget.welcomeMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.welcomeMessage!)),
        );
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _createAccountRecognizer.dispose();
    super.dispose();
  }

  void _handleCreateAccount() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ApiClient.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(username: _usernameController.text.trim()),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the server. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1440), Color(0xFF1B2A6B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('💰', style: TextStyle(fontSize: 26)),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Financial Planner',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: _primaryBlue,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Financial Planner — sign in to continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _FieldLabel('USERNAME'),
                        const SizedBox(height: 8),
                        _StyledTextField(
                          controller: _usernameController,
                          hintText: 'Enter your username',
                          fillColor: _fieldFill,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel('PASSWORD'),
                        const SizedBox(height: 8),
                        _StyledTextField(
                          controller: _passwordController,
                          hintText: 'Enter your password',
                          fillColor: _fieldFill,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              children: [
                                const TextSpan(text: 'No account? '),
                                TextSpan(
                                  text: 'Create one',
                                  style: const TextStyle(
                                    color: _primaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: _createAccountRecognizer,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Colors.grey.shade700,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color fillColor;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.hintText,
    required this.fillColor,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: fillColor,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A3EDB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
    );
  }
}
