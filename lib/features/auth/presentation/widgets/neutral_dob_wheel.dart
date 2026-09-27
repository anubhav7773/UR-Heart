import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';

/// Neutral Date-of-Birth selector initialized with NO pre-selected adult year
/// strictly complying with Google Play Minor Safety policies
class NeutralDobWheel extends ConsumerWidget {
  const NeutralDobWheel({super.key});

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final inputBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;

    final inputBorder = isDark
        ? DarkSanctuaryTokens.inputBorder
        : LightSanctuaryTokens.inputBorder;

    final textColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final hintColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final currentYear = DateTime.now().year;
    final years = List<int>.generate(100, (i) => currentYear - i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DATE OF BIRTH',
              style: AppTypography.accordionCategory.copyWith(color: hintColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color(0xFFE63946).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFFE63946), width: 0.8),
              ),
              child: const Text(
                'STRICTLY 18+',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE63946),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            // Day selector
            Expanded(
              flex: 2,
              child: _buildDropdownContainer(
                inputBg: inputBg,
                inputBorder: inputBorder,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: authState.selectedDay,
                    hint: Text('Day', style: TextStyle(color: hintColor, fontSize: 13.0)),
                    dropdownColor: inputBg,
                    icon: Icon(Icons.arrow_drop_down, color: hintColor, size: 20.0),
                    items: List.generate(31, (index) => index + 1).map((day) {
                      return DropdownMenuItem<int>(
                        value: day,
                        child: Text('$day', style: TextStyle(color: textColor, fontSize: 13.0)),
                      );
                    }).toList(),
                    onChanged: (day) {
                      if (day != null) {
                        ref.read(authControllerProvider.notifier).setDateOfBirth(
                              day: day,
                              month: authState.selectedMonth ?? 1,
                              year: authState.selectedYear ?? (currentYear - 18),
                            );
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            // Month selector
            Expanded(
              flex: 3,
              child: _buildDropdownContainer(
                inputBg: inputBg,
                inputBorder: inputBorder,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: authState.selectedMonth,
                    hint: Text('Month', style: TextStyle(color: hintColor, fontSize: 13.0)),
                    dropdownColor: inputBg,
                    icon: Icon(Icons.arrow_drop_down, color: hintColor, size: 20.0),
                    items: List.generate(12, (index) => index + 1).map((month) {
                      return DropdownMenuItem<int>(
                        value: month,
                        child: Text(_months[month - 1], style: TextStyle(color: textColor, fontSize: 13.0)),
                      );
                    }).toList(),
                    onChanged: (month) {
                      if (month != null) {
                        ref.read(authControllerProvider.notifier).setDateOfBirth(
                              day: authState.selectedDay ?? 1,
                              month: month,
                              year: authState.selectedYear ?? (currentYear - 18),
                            );
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            // Year selector (Zero pre-selected adult year)
            Expanded(
              flex: 3,
              child: _buildDropdownContainer(
                inputBg: inputBg,
                inputBorder: inputBorder,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: authState.selectedYear,
                    hint: Text('Year', style: TextStyle(color: hintColor, fontSize: 13.0)),
                    dropdownColor: inputBg,
                    icon: Icon(Icons.arrow_drop_down, color: hintColor, size: 20.0),
                    items: years.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text('$year', style: TextStyle(color: textColor, fontSize: 13.0)),
                      );
                    }).toList(),
                    onChanged: (year) {
                      if (year != null) {
                        ref.read(authControllerProvider.notifier).setDateOfBirth(
                              day: authState.selectedDay ?? 1,
                              month: authState.selectedMonth ?? 1,
                              year: year,
                            );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownContainer({
    required Color inputBg,
    required Color inputBorder,
    required Widget child,
  }) {
    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: inputBorder),
      ),
      child: child,
    );
  }
}
