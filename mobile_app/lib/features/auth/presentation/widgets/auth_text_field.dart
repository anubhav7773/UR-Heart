import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Reusable Obsidian Dark Text Field for Authentication forms
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onEditingComplete,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      enabled: enabled,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: AppTheme.primaryColor,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF171822),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelText: labelText,
        labelStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: const Color(0xFF9CA3AF),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF252736), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF252736), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFF87171),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
