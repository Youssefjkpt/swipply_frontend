import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

class _LeftClipper extends CustomClipper<Rect> {
  final double x;
  _LeftClipper({required this.x});

  @override
  Rect getClip(Size size) => Rect.fromLTWH(x, 0, size.width - x, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) => oldClipper.x != x;
}

class _RightClipper extends CustomClipper<Rect> {
  final double x;
  _RightClipper({required this.x});

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(covariant _RightClipper oldClipper) => oldClipper.x != x;
}

class WaveWipeTextSwitcher extends StatefulWidget {
  final String text;

  const WaveWipeTextSwitcher({super.key, required this.text});

  @override
  State<WaveWipeTextSwitcher> createState() => _WaveWipeTextSwitcherState();
}

class _WaveWipeTextSwitcherState extends State<WaveWipeTextSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  String _currentText = '';
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
    _previousText = '';
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward(); // ✅ Trigger animation on first load
  }

  @override
  void didUpdateWidget(covariant WaveWipeTextSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _previousText = _currentText;
      _currentText = widget.text;
      _controller.forward(from: 0); // ✅ Trigger animation on new upload
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.6;
    const height = 24.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        final splitX = width * progress;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  clipper: _LeftClipper(x: splitX),
                  child: Text(
                    _previousText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: white_gray,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRect(
                  clipper: _RightClipper(x: splitX),
                  child: Opacity(
                    opacity: progress,
                    child: Text(
                      _currentText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: white_gray,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
