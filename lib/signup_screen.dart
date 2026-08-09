import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _primaryBlue = Color(0xFF2A3EDB);
  static const _fieldFill = Color(0xFFE8ECFB);

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _selectedInr = false;
  bool _selectedSgd = false;
  late final TapGestureRecognizer _signInRecognizer;

  @override
  void initState() {
    super.initState();
    _signInRecognizer = TapGestureRecognizer()..onTap = _handleSignInTap;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _signInRecognizer.dispose();
    super.dispose();
  }

  void _handleSignInTap() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_selectedInr && !_selectedSgd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one currency')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiClient.signup(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        currencies: [
          if (_selectedInr) 'INR',
          if (_selectedSgd) 'SGD',
        ],
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            welcomeMessage: 'Account created! Please log in.',
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                            'Create your account',
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
                          hintText: 'choose a username',
                          fillColor: _fieldFill,
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.length < 3) {
                              return 'Min 3 characters';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
                              return 'Letters, numbers, - and _ only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Min 3 characters. Letters, numbers, - and _ only.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                            if (value == null || value.length < 6) {
                              return 'At least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'At least 6 characters.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel('CONFIRM PASSWORD'),
                        const SizedBox(height: 8),
                        _StyledTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Re-enter your password',
                          fillColor: _fieldFill,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword = !_obscureConfirmPassword,
                              );
                            },
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel('CURRENCIES'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _CurrencyOption(
                                label: '₹ INR',
                                selected: _selectedInr,
                                onChanged: (value) {
                                  setState(() => _selectedInr = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CurrencyOption(
                                label: 'S\$ SGD',
                                selected: _selectedSgd,
                                onChanged: (value) {
                                  setState(() => _selectedSgd = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Select at least one currency you'll track loans in.",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleCreateAccount,
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
                                    'Create Account',
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
                                const TextSpan(text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Sign in',
                                  style: const TextStyle(
                                    color: _primaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: _signInRecognizer,
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

class _CurrencyOption extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _CurrencyOption({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFF2A3EDB) : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
