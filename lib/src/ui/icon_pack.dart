import 'package:flutter/material.dart';

enum AppGlyph { home, bookings, bell, user, plus }

class AppGlyphIcon extends StatelessWidget {
  const AppGlyphIcon({
    super.key,
    required this.glyph,
    this.size = 20,
    this.color,
    this.strokeWidth = 1.9,
  });

  final AppGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? IconTheme.of(context).color ?? Colors.black;
    return CustomPaint(
      size: Size.square(size),
      painter: _AppGlyphPainter(
        glyph: glyph,
        color: resolvedColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _AppGlyphPainter extends CustomPainter {
  const _AppGlyphPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final AppGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    switch (glyph) {
      case AppGlyph.home:
        final roof = Path()
          ..moveTo(size.width * 0.16, size.height * 0.49)
          ..lineTo(size.width * 0.5, size.height * 0.2)
          ..lineTo(size.width * 0.84, size.height * 0.49);
        canvas.drawPath(roof, stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.24,
              size.height * 0.48,
              size.width * 0.52,
              size.height * 0.35,
            ),
            Radius.circular(size.width * 0.08),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.44,
              size.height * 0.6,
              size.width * 0.12,
              size.height * 0.23,
            ),
            Radius.circular(size.width * 0.04),
          ),
          stroke,
        );
      case AppGlyph.bookings:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.18,
              size.height * 0.24,
              size.width * 0.64,
              size.height * 0.62,
            ),
            Radius.circular(size.width * 0.1),
          ),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.31, size.height * 0.16),
          Offset(size.width * 0.31, size.height * 0.31),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.69, size.height * 0.16),
          Offset(size.width * 0.69, size.height * 0.31),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.28, size.height * 0.46),
          Offset(size.width * 0.72, size.height * 0.46),
          stroke,
        );
      case AppGlyph.bell:
        final bell = Path()
          ..moveTo(size.width * 0.3, size.height * 0.56)
          ..lineTo(size.width * 0.3, size.height * 0.47)
          ..quadraticBezierTo(
            size.width * 0.3,
            size.height * 0.26,
            size.width * 0.5,
            size.height * 0.26,
          )
          ..quadraticBezierTo(
            size.width * 0.7,
            size.height * 0.26,
            size.width * 0.7,
            size.height * 0.47,
          )
          ..lineTo(size.width * 0.7, size.height * 0.56)
          ..lineTo(size.width * 0.8, size.height * 0.66)
          ..lineTo(size.width * 0.2, size.height * 0.66)
          ..close();
        canvas.drawPath(bell, stroke);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.76),
          size.width * 0.05,
          fill,
        );
      case AppGlyph.user:
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.37),
          size.width * 0.16,
          stroke,
        );
        final body = Path()
          ..moveTo(size.width * 0.25, size.height * 0.78)
          ..quadraticBezierTo(
            size.width * 0.5,
            size.height * 0.57,
            size.width * 0.75,
            size.height * 0.78,
          );
        canvas.drawPath(body, stroke);
      case AppGlyph.plus:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.25),
          Offset(size.width * 0.5, size.height * 0.75),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.25, size.height * 0.5),
          Offset(size.width * 0.75, size.height * 0.5),
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _AppGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
