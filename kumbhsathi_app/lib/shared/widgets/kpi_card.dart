import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'animated_count.dart';
import 'app_card.dart';

/// KPI card: tonal icon chip, animated numeral, optional delta pill and
/// mini sparkline (DESIGN.md §5).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.containerColor = AppColors.primaryContainer,
    this.deltaLabel,
    this.deltaPositive,
    this.sparkline,
    this.suffix = '',
    this.decimals = 0,
    this.onTap,
  });

  final String label;
  final num value;
  final IconData icon;
  final Color color;
  final Color containerColor;

  /// e.g. "+12% vs yesterday". Colored by [deltaPositive].
  final String? deltaLabel;
  final bool? deltaPositive;

  /// 5–10 points; rendered as a soft area sparkline, no axes.
  final List<double>? sparkline;
  final String suffix;
  final int decimals;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final good = deltaPositive ?? true;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (deltaLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: good
                        ? AppColors.successContainer
                        : AppColors.dangerContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        good
                            ? Symbols.trending_up
                            : Symbols.trending_down,
                        size: 13,
                        color:
                            good ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        deltaLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              good ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedCount(
            value,
            decimals: decimals,
            suffix: suffix,
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (sparkline != null && sparkline!.length >= 2) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 36, child: _Sparkline(sparkline!, color)),
          ],
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline(this.points, this.color);
  final List<double> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: points.reduce((a, b) => a < b ? a : b) * 0.9,
        maxY: points.reduce((a, b) => a > b ? a : b) * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.4,
            color: color,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: AppMotion.enter,
    );
  }
}
