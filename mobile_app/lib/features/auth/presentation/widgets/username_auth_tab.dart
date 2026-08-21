import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'auth_text_field.dart';

/// Username & Password Authentication Tab for users who prefer handle-based login.
class UsernameAuthTab extends StatefulWidget {
  final bool isSignUp;
  final bool isLoading;
  final Future<void> Function(String username, String password) onSubmit;

  const UsernameAuthTab({
    super.key,
    required this.isSignUp,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<UsernameAuthTab> createState() => _UsernameAuthTabState();
}

class _UsernameAuthTabState extends State<UsernameAuthTab> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSubmit(
      _usernameController.text.trim(),
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
          // 1. Username Handle Field
          AuthTextField(
            controller: _usernameController,
            hintText: 'aarav_sharma',
            labelText: 'Username Handle',
            prefixIcon: Icons.alternate_email_rounded,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
              LengthLimitingTextInputFormatter(25),
            ],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your username';
              }
              if (val.trim().length < 3) {
                return 'Username must be at least 3 characters';
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
          const SizedBox(height: 18),

          // 3. Submit CTA
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
                    widget.isSignUp ? 'Claim Username & Join' : 'Sign In with Username',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
