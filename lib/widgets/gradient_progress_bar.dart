import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

class GradientProgressBar extends StatelessWidget {
  final double value;

  const GradientProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: black_gray,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.redAccent,
                            Colors.deepOrangeAccent,
                            Colors.orangeAccent,
                            Colors.blueAccent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
