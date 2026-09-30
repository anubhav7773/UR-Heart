import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../domain/chat_models.dart';

/// Horizontal carousel displaying recent resonance sparks with online state (< 150 lines)
class RecentSparksCarousel extends StatelessWidget {
  final List<SparkProfile> sparks;
  final bool isDark;
  final ValueChanged<SparkProfile> onSparkTap;

  const RecentSparksCarousel({
    super.key,
    required this.sparks,
    required this.isDark,
    required this.onSparkTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sparks.isEmpty) return const SizedBox.shrink();

    final headline = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
          child: Row(
            children: [
              Text('Recent Sparks ✨', style: AppTypography.titleH2.copyWith(color: headline, fontSize: 16.0)),
              const SizedBox(width: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: pine.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  '${sparks.length}',
                  style: AppTypography.caption.copyWith(color: pine, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 104.0,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: sparks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14.0),
            itemBuilder: (context, index) => _buildSparkItem(context, sparks[index], cardBorder, pine),
          ),
        ),
      ],
    );
  }

  Widget _buildSparkItem(BuildContext context, SparkProfile spark, Color borderColor, Color pine) {
    final textColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final badgeColor = isDark ? DarkSanctuaryTokens.badgeOnline : LightSanctuaryTokens.badgeOnline;
    final isMutual = spark.matchType == 'MUTUAL';
    final tagBg = isMutual ? pine : (isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.chipBackground);
    final tagFg = isMutual ? Colors.white : (isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textBody);

    return InkWell(
      onTap: () => onSparkTap(spark),
      borderRadius: BorderRadius.circular(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 58.0,
                height: 58.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.chipBackground,
                  border: Border.all(color: borderColor, width: 2.0),
                  image: spark.avatarUrl.isNotEmpty && spark.avatarUrl.startsWith('http')
                      ? DecorationImage(
                          image: NetworkImage(spark.avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (spark.avatarUrl.isEmpty || !spark.avatarUrl.startsWith('http'))
                    ? Center(
                        child: Text(
                          spark.name.isNotEmpty ? spark.name[0] : 'S',
                          style: AppTypography.titleH2.copyWith(color: pine, fontSize: 20.0),
                        ),
                      )
                    : null,
              ),
              if (spark.isOnline)
                Positioned(
                  right: 2.0,
                  bottom: 2.0,
                  child: Container(
                    width: 12.0,
                    height: 12.0,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(spark.name, style: AppTypography.caption.copyWith(color: textColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(6.0)),
            child: Text(spark.matchType, style: TextStyle(color: tagFg, fontSize: 8.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
