import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/currency_formatter.dart';

class CategoryDonutChart extends StatelessWidget {
  final Map<String, double> categoryCosts;
  final double total;

  const CategoryDonutChart({
    super.key,
    required this.categoryCosts,
    required this.total,
  });

  static const List<Color> _palette = [
    AppColors.emerald,
    AppColors.indigo,
    AppColors.amber,
    AppColors.crimson,
    Color(0xFF0284C7),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    if (categoryCosts.isEmpty || total <= 0) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          'No expense data to display',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
        ),
      );
    }

    // Sort categories by cost descending
    final entries = categoryCosts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Total Spent',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 12,
                color: AppColors.getTextMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              CurrencyFormatter.format(total, compact: true),
              style: AppTextStyles.currencySmall.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(entries.length, (i) {
          final e = entries[i];
          final color = _palette[i % _palette.length];
          final double percent = total > 0 ? (e.value / total) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}% • ${CurrencyFormatter.format(e.value, compact: true)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.getTextMuted(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class SpendingTrendLineChart extends StatelessWidget {
  final List<double> monthlyValues;
  final List<String> monthLabels;

  const SpendingTrendLineChart({
    super.key,
    required this.monthlyValues,
    required this.monthLabels,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    if (monthlyValues.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Text(
          'No trend data available',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
        ),
      );
    }

    final double maxY = monthlyValues.reduce((a, b) => a > b ? a : b) * 1.25;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 3 : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < monthLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        monthLabels[index],
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          color: AppColors.getTextMuted(context),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    CurrencyFormatter.format(value, compact: true),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 10,
                      color: AppColors.getTextMuted(context),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (monthlyValues.length - 1).toDouble(),
          minY: 0,
          maxY: maxY > 0 ? maxY : 100,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                monthlyValues.length,
                (i) => FlSpot(i.toDouble(), monthlyValues[i]),
              ),
              isCurved: true,
              color: primaryColor,
              barWidth: 2.8,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.getSurface(context),
                  strokeWidth: 2.2,
                  strokeColor: primaryColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: isDark ? 0.25 : 0.14),
                    primaryColor.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
