import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MinimalAreaChart extends StatefulWidget {
  final String title;
  final String? subtitle;

  const MinimalAreaChart({
    super.key,
    this.title = 'Monthly Earnings',
    this.subtitle,
  });

  @override
  State<MinimalAreaChart> createState() => _MinimalAreaChartState();
}

class _MinimalAreaChartState extends State<MinimalAreaChart> {
  String _selectedPeriod = 'This Month';

  final List<double> _dataPoints = [2.5, 4.8, 3.2, 6.1, 4.0, 5.5, 6.8];
  final List<String> _xLabels = ['1 Apr', '6 Apr', '10 Apr', '16 Apr', '20 Apr', '30 Apr'];
  final List<String> _yLabels = ['10k', '8k', '7k', '5k', '2k', '0\$'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Timeframe Selector (Image 2 style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF4F46E5)),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF4F46E5),
                    ),
                    dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                      DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
                      DropdownMenuItem(value: 'This Quarter', child: Text('This Quarter')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPeriod = val);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Chart Canvas with Tooltip & Y-Axis Labels
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-Axis Labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _yLabels.map((lbl) {
                    return Text(
                      lbl,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(width: 8),

                // Curved Area Chart Canvas
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _AreaChartPainter(
                          dataPoints: _dataPoints,
                          maxY: 10.0,
                          isDark: isDark,
                          tooltipValue: '\$6,100',
                          tooltipIndex: 3, // Point 4 (index 3) is the peak $6,100
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // X-Axis Labels
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _xLabels.map((lbl) {
                return Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final double maxY;
  final bool isDark;
  final String tooltipValue;
  final int tooltipIndex;

  _AreaChartPainter({
    required this.dataPoints,
    required this.maxY,
    required this.isDark,
    required this.tooltipValue,
    required this.tooltipIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9))
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    const gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Compute point coordinates
    final points = <Offset>[];
    final dx = size.width / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * dx;
      final normalizedY = (dataPoints[i] / maxY).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * size.height * 0.85); // give margin at top for tooltip
      points.add(Offset(x, y));
    }

    // Build smooth Bezier path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Fill area below the curve with gradient
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF6366F1).withAlpha(60),
          const Color(0xFF6366F1).withAlpha(15),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke the curved line
    final strokePaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Draw small circular points
    final dotFillPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 3.5, dotFillPaint);
      canvas.drawCircle(points[i], 3.5, dotBorderPaint);
    }

    // Draw Floating Tooltip Bubble over the peak point (index 3)
    if (tooltipIndex >= 0 && tooltipIndex < points.length) {
      final peak = points[tooltipIndex];
      _drawTooltip(canvas, peak);
    }
  }

  void _drawTooltip(Canvas canvas, Offset target) {
    const bubbleWidth = 62.0;
    const bubbleHeight = 28.0;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(target.dx, target.dy - 22),
        width: bubbleWidth,
        height: bubbleHeight,
      ),
      const Radius.circular(10),
    );

    // Tooltip shadow
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = const Color(0xFF4F46E5).withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Tooltip body
    final bubblePaint = Paint()..color = const Color(0xFF4F46E5);
    canvas.drawRRect(bubbleRect, bubblePaint);

    // Tooltip pointer triangle
    final arrowPath = Path()
      ..moveTo(target.dx - 5, target.dy - 8)
      ..lineTo(target.dx + 5, target.dy - 8)
      ..lineTo(target.dx, target.dy - 2)
      ..close();
    canvas.drawPath(arrowPath, bubblePaint);

    // Tooltip text
    final textPainter = TextPainter(
      text: TextSpan(
        text: tooltipValue,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        target.dx - (textPainter.width / 2),
        target.dy - 22 - (textPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.isDark != isDark ||
        oldDelegate.tooltipValue != tooltipValue;
  }
}
