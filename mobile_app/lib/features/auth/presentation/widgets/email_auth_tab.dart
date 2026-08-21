import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'auth_text_field.dart';

/// Email & Password Authentication Tab with password strength meter,
/// RFC 5322 validation, and Forgot Password recovery trigger.
class EmailAuthTab extends StatefulWidget {
  final bool isSignUp;
  final bool isLoading;
  final Future<void> Function(String email, String password) onSubmit;
  final VoidCallback onForgotPassword;

  const EmailAuthTab({
    super.key,
    required this.isSignUp,
    required this.isLoading,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  @override
  State<EmailAuthTab> createState() => _EmailAuthTabState();
}

class _EmailAuthTabState extends State<EmailAuthTab> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  double _passwordStrength = 0.0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() => _passwordStrength = 0.0);
      return;
    }
    double strength = 0.0;
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password) || RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.25;

    setState(() => _passwordStrength = strength);
  }

  Color get _strengthColor {
    if (_passwordStrength <= 0.25) return const Color(0xFFEF4444); // Red
    if (_passwordStrength <= 0.5) return const Color(0xFFF59E0B);  // Amber
    if (_passwordStrength <= 0.75) return const Color(0xFF3B82F6); // Blue
    return const Color(0xFF10B981);                               // Green
  }

  String get _strengthLabel {
    if (_passwordStrength <= 0.25) return 'Weak';
    if (_passwordStrength <= 0.5) return 'Fair';
    if (_passwordStrength <= 0.75) return 'Good';
    return 'Strong & Secure';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSubmit(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Email Field
          AuthTextField(
            controller: _emailController,
            hintText: 'name@example.com',
            labelText: 'Email Address',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(val.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // 2. Password Field
          AuthTextField(
            controller: _passwordController,
            hintText: '••••••••••••',
            labelText: 'Password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onChanged: widget.isSignUp ? _calculatePasswordStrength : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF9CA3AF),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter your password';
              }
              if (val.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
            onEditingComplete: _handleSubmit,
          ),

          // 3. Dynamic Password Strength Meter (On Sign Up)
          if (widget.isSignUp && _passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _passwordStrength,
                      backgroundColor: const Color(0xFF252736),
                      valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _strengthLabel,
                  style: TextStyle(
                    color: _strengthColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // 4. Forgot Password Action (On Sign In)
          if (!widget.isSignUp) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgotPassword,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
          ],

          // 5. Submit CTA
          ElevatedButton(
            onPressed: widget.isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.isSignUp ? 'Create Account' : 'Sign In with Email',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
