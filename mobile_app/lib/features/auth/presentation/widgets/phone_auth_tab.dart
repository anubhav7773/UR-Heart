import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'auth_text_field.dart';

/// Phone / SMS OTP Authentication Tab with country code selector,
/// 6-digit PIN input, and 30-second resend countdown timer.
class PhoneAuthTab extends StatefulWidget {
  final bool isSignUp;
  final bool isLoading;
  final Future<bool> Function(String fullPhoneNumber) onSendOtp;
  final Future<void> Function(String fullPhoneNumber, String otpCode) onVerifyOtp;

  const PhoneAuthTab({
    super.key,
    required this.isSignUp,
    required this.isLoading,
    required this.onSendOtp,
    required this.onVerifyOtp,
  });

  @override
  State<PhoneAuthTab> createState() => _PhoneAuthTabState();
}

class _PhoneAuthTabState extends State<PhoneAuthTab> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _countryCode = '+91';
  bool _otpSent = false;
  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.disposenatural();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _fullPhoneNumber => '$_countryCode${_phoneController.text.trim()}';

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final success = await widget.onSendOtp(_fullPhoneNumber);
    if (success && mounted) {
      setState(() => _otpSent = true);
      _startResendTimer();
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP code'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await widget.onVerifyOtp(_fullPhoneNumber, code);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_otpSent) ...[
            // 1. Phone Number Input with Country Code Selector
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country Code Button
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171822),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF252736), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        _countryCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 10-Digit Mobile Number
                Expanded(
                  child: AuthTextField(
                    controller: _phoneController,
                    hintText: '98765 43210',
                    prefixIcon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter mobile number';
                      }
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(val.trim())) {
                        return 'Enter valid 10-digit number';
                      }
                      return null;
                    },
                    onEditingComplete: _handleSendOtp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Send OTP CTA
            ElevatedButton(
              onPressed: widget.isLoading ? null : _handleSendOtp,
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
                      widget.isSignUp ? 'Get Verification OTP' : 'Send Login Code',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ] else ...[
            // 2. 6-Digit OTP View
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF13141F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF252736), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Code sent to $_fullPhoneNumber',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                          });
                        },
                        child: const Text(
                          'Change',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6-digit OTP Input
                  AuthTextField(
                    controller: _otpController,
                    hintText: '• • • • • •',
                    prefixIcon: Icons.lock_clock_outlined,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      if (val.length == 6) {
                        _handleVerifyOtp();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Verify & Proceed CTA
            ElevatedButton(
              onPressed: widget.isLoading ? null : _handleVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  : const Text(
                      'Verify & Continue',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 12),

            // Resend Code Countdown
            Center(
              child: _resendCountdown > 0
                  ? Text(
                      'Resend code in ${_resendCountdown}s',
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    )
                  : GestureDetector(
                      onTap: widget.isLoading ? null : _handleSendOtp,
                      child: const Text(
                        'Resend OTP Code',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on TextEditingController {
  void disposenatural() {
    dispose();
  }
}
