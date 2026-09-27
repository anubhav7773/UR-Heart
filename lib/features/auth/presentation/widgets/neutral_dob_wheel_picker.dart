import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../controllers/age_gate_controller.dart';
import '../controllers/auth_controller.dart';

class NeutralDobWheelPicker extends ConsumerStatefulWidget {
  const NeutralDobWheelPicker({super.key});

  @override
  ConsumerState<NeutralDobWheelPicker> createState() => _NeutralDobWheelPickerState();
}

class _NeutralDobWheelPickerState extends ConsumerState<NeutralDobWheelPicker> {
  int _selectedDay = 15;
  int _selectedMonth = 6;
  int? _selectedYear;

  final List<String> _months = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final ageState = ref.watch(ageGateControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final danger = isDark ? DarkSanctuaryTokens.dangerBorder : LightSanctuaryTokens.dangerBorder;

    final currentYear = DateTime.now().year;
    final years = List.generate(85, (index) => currentYear - index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Date of Birth', style: TextStyle(fontWeight: FontWeight.w600, color: primaryText)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'STRICTLY 18+',
                style: TextStyle(color: danger, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: _selectedDay - 1),
                  onSelectedItemChanged: (idx) {
                    setState(() => _selectedDay = idx + 1);
                    _notifyChange();
                  },
                  children: List.generate(31, (i) => Center(child: Text('${i + 1}', style: TextStyle(color: primaryText)))),
                ),
              ),
              Expanded(
                flex: 3,
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: _selectedMonth - 1),
                  onSelectedItemChanged: (idx) {
                    setState(() => _selectedMonth = idx + 1);
                    _notifyChange();
                  },
                  children: _months.map((m) => Center(child: Text(m, style: TextStyle(color: primaryText)))).toList(),
                ),
              ),
              Expanded(
                flex: 3,
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: 0),
                  onSelectedItemChanged: (idx) {
                    if (idx == 0) {
                      setState(() => _selectedYear = null);
                    } else {
                      setState(() => _selectedYear = years[idx - 1]);
                    }
                    _notifyChange();
                  },
                  children: [
                    Center(child: Text('Select Year', style: TextStyle(color: subText, fontSize: 13))),
                    ...years.map((y) => Center(child: Text('$y', style: TextStyle(color: primaryText)))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedYear != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: ageState.isAdult ? pine.withValues(alpha: 0.12) : danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ageState.isAdult ? pine : danger, width: 0.8),
            ),
            child: Text(
              ageState.statusBadgeText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ageState.isAdult ? pine : danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _notifyChange() {
    final year = _selectedYear;
    if (year != null) {
      final dob = DateTime(year, _selectedMonth, _selectedDay);
      ref.read(ageGateControllerProvider.notifier).evaluateDob(dob);
      ref.read(authControllerProvider.notifier).setDateOfBirth(
        day: _selectedDay,
        month: _selectedMonth,
        year: year,
      );
    }
  }
}
