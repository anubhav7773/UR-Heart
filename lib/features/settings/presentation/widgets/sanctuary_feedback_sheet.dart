import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sentry_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../ai_sanctuary/data/ai_sanctuary_repository.dart';

class SanctuaryFeedbackSheet extends ConsumerStatefulWidget {
  const SanctuaryFeedbackSheet({super.key});

  @override
  ConsumerState<SanctuaryFeedbackSheet> createState() => _SanctuaryFeedbackSheetState();
}

class _SanctuaryFeedbackSheetState extends ConsumerState<SanctuaryFeedbackSheet> {
  final TextEditingController _textController = TextEditingController();
  String _selectedCategory = 'bug_report';
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<Map<String, String>> _categories = [
    {'id': 'bug_report', 'label': '🐞 Bug Report', 'desc': 'Something didn\'t work as expected'},
    {'id': 'feature_suggestion', 'label': '💡 Suggest Feature', 'desc': 'An idea to make UR-Heart better'},
    {'id': 'ux_improvement', 'label': '🎨 UI & Design', 'desc': 'Look, feel, or navigation flow'},
    {'id': 'general', 'label': '💬 General Thought', 'desc': 'Any other thoughts or reflections'},
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _getPlatformSummary() {
    if (kIsWeb) return 'Web Browser';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      return Platform.operatingSystem;
    } catch (_) {
      return 'Mobile App';
    }
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please describe your bug or suggestion.';
      });
      return;
    }

    if (text.length < 5) {
      setState(() {
        _errorMessage = 'Please provide a bit more detail (at least 5 characters).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    final platform = _getPlatformSummary();
    const appVersion = '1.0.0+1';

    final diagnostics = {
      'platform': platform,
      'app_version': appVersion,
      'screen': 'SanctuarySettings',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Submit to Sentry Observability
    await SentryService.captureUserFeedback(
      category: _selectedCategory,
      description: text,
      diagnostics: diagnostics,
    );

    // 2. Submit to Backend API & Founder Email Alert
    bool backendSuccess = false;
    try {
      final repo = ref.read(aiSanctuaryRepositoryProvider);
      backendSuccess = await repo.submitFeedback(
        description: text,
        category: _selectedCategory,
        appVersion: appVersion,
        platformOs: platform,
        deviceModel: platform,
        screenRoute: 'SanctuarySettings',
      );
    } catch (_) {}

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                backendSuccess
                    ? 'Thank you! Your feedback has been sent to our core engineering team.'
                    : 'Report captured securely. Thank you for making UR-Heart better!',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.isDark;

    final bgColor = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final headlineColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final primaryAccent = isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.primaryPine;
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.rate_review_rounded, color: primaryAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community Feedback & Bug Portal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: headlineColor,
                        ),
                      ),
                      Text(
                        'Direct line to our core engineering team',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: mutedColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Category selector
            Text(
              'WHAT WOULD YOU LIKE TO SHARE?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  label: Text(
                    cat['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : headlineColor,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: primaryAccent,
                  backgroundColor: inputBg,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat['id']!;
                        _errorMessage = null;
                      });
                      HapticFeedback.selectionClick();
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Description textfield
            Text(
              'DESCRIPTION & DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _textController,
              maxLines: 4,
              maxLength: 1000,
              style: TextStyle(color: headlineColor, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                hintText: _selectedCategory == 'bug_report'
                    ? 'What happened? e.g. "Screen was stuck on swipe, error showed up..."'
                    : 'Share your idea or thoughts with us...',
                hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.6), fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryAccent, width: 1.5),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
              ),
            ],

            // Diagnostics banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryAccent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: primaryAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diagnostics attached: ${_getPlatformSummary()} • v1.0.0+1 • DPDP Sanitized',
                      style: TextStyle(fontSize: 11, color: headlineColor.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit to Sanctuary Team',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
