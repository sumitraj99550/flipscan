import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/edge_result.dart';

class EdgeOverlayPainter extends CustomPainter {
  final ScanState scanState;
  final double stabilityProgress;

  EdgeOverlayPainter({
    required this.scanState,
    required this.stabilityProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = _stateColor;
    final isFlipping = scanState == ScanState.flipping;
    final isStable = scanState == ScanState.stable;

    // Darkened border vignette
    final vigPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vigPaint);

    // Guide rectangle
    final margin = size.width * 0.05;
    final rect = Rect.fromLTRB(
      margin,
      size.height * 0.1,
      size.width - margin,
      size.height * 0.9,
    );

    // Dashed or solid border
    if (isFlipping) {
      _drawDashedRect(
        canvas,
        rect,
        Colors.orange.withValues(alpha: 0.6),
        2.5,
      );
    } else {
      _drawCornerBrackets(canvas, rect, color,
          isStable ? 4.0 : 2.5, isStable ? 28.0 : 22.0);
    }

    // Stability progress arc
    if (isStable && stabilityProgress > 0) {
      _drawStabilityArc(canvas, rect, stabilityProgress, color);
    }
  }

  Color get _stateColor {
    switch (scanState) {
      case ScanState.stable:
        return AppTheme.successColor;
      case ScanState.flipping:
        return Colors.orange;
      case ScanState.capturing:
        return Colors.white;
      case ScanState.paused:
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color,
      double strokeWidth, double bracketLength) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      // Top-left
      [
        Offset(rect.left, rect.top + bracketLength),
        Offset(rect.left, rect.top),
        Offset(rect.left + bracketLength, rect.top),
      ],
      // Top-right
      [
        Offset(rect.right - bracketLength, rect.top),
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.top + bracketLength),
      ],
      // Bottom-right
      [
        Offset(rect.right, rect.bottom - bracketLength),
        Offset(rect.right, rect.bottom),
        Offset(rect.right - bracketLength, rect.bottom),
      ],
      // Bottom-left
      [
        Offset(rect.left + bracketLength, rect.bottom),
        Offset(rect.left, rect.bottom),
        Offset(rect.left, rect.bottom - bracketLength),
      ],
    ];

    for (final corner in corners) {
      final path = Path()..moveTo(corner[0].dx, corner[0].dy);
      for (int i = 1; i < corner.length; i++) {
        path.lineTo(corner[i].dx, corner[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawDashedRect(
      Canvas canvas, Rect rect, Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashLength = 12.0;
    const gapLength = 8.0;

    _drawDashedLine(
        canvas, rect.topLeft, rect.topRight, paint, dashLength, gapLength);
    _drawDashedLine(
        canvas, rect.topRight, rect.bottomRight, paint, dashLength, gapLength);
    _drawDashedLine(
        canvas, rect.bottomRight, rect.bottomLeft, paint, dashLength, gapLength);
    _drawDashedLine(
        canvas, rect.bottomLeft, rect.topLeft, paint, dashLength, gapLength);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      double dash, double gap) {
    final totalLen = (end - start).distance;
    final dir = (end - start) / totalLen;
    double pos = 0;
    bool drawing = true;

    while (pos < totalLen) {
      final segLen = drawing ? dash : gap;
      final next = pos + segLen;
      if (drawing) {
        canvas.drawLine(
          start + dir * pos,
          start + dir * next.clamp(0, totalLen),
          paint,
        );
      }
      pos = next;
      drawing = !drawing;
    }
  }

  void _drawStabilityArc(
      Canvas canvas, Rect rect, double progress, Color color) {
    final center = rect.center;
    const radius = 28.0;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(arcRect, -1.5708, 6.2832, false, bgPaint);
    canvas.drawArc(arcRect, -1.5708, 6.2832 * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(EdgeOverlayPainter old) =>
      old.scanState != scanState ||
      old.stabilityProgress != stabilityProgress;
}
