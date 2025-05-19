import 'dart:math';

import 'package:flutter/material.dart';

class AnimatedCheckMark extends StatefulWidget {
  final double size;

  const AnimatedCheckMark({super.key, this.size = 60});

  @override
  State<AnimatedCheckMark> createState() => _AnimatedCheckMarkState();
}

class _AnimatedCheckMarkState extends State<AnimatedCheckMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: CheckMarkPainter(_animation),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class CheckMarkPainter extends CustomPainter {
  final Animation<double> animation;

  CheckMarkPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double progress = animation.value;

    final double radius = (size.width / 2) - 6;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // 1. Draw circular progress arc (0.0 to 0.6)
    if (progress <= 0.6) {
      final double sweepAngle = 2 * pi * (progress / 0.6);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        paint,
      );
    }

    // 2. Draw checkmark after 0.6
    if (progress > 0.6) {
      // Draw full circle first
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi,
        false,
        paint,
      );

      final double t = (progress - 0.6) / 0.4;
      final Offset start = Offset(size.width * 0.28, size.height * 0.52);
      final Offset mid = Offset(size.width * 0.45, size.height * 0.68);
      final Offset end = Offset(size.width * 0.72, size.height * 0.38);

      final Path path = Path();
      if (t < 0.5) {
        final Offset current = Offset.lerp(start, mid, t * 2)!;
        path.moveTo(start.dx, start.dy);
        path.lineTo(current.dx, current.dy);
      } else {
        final Offset current = Offset.lerp(mid, end, (t - 0.5) * 2)!;
        path.moveTo(start.dx, start.dy);
        path.lineTo(mid.dx, mid.dy);
        path.lineTo(current.dx, current.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CheckMarkPainter oldDelegate) => true;
}
