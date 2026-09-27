import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';

/// Styled input field for email and credentials in auth flows
class AuthCredentialField extends StatelessWidget {
  final String label;
  final String hintText;
  final Color inputBg;
  final Color inputBorder;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;

  const AuthCredentialField({
    super.key,
    required this.label,
    required this.hintText,
    required this.inputBg,
    required this.inputBorder,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
        const SizedBox(height: 6.0),
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: inputBorder),
          ),
          child: TextField(
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(color: textColor, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: mutedColor, fontSize: 14.0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              suffixIcon: suffixIcon,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
