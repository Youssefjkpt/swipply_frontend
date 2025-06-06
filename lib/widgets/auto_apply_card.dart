import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

class AutoApplyBadge extends StatefulWidget {
  const AutoApplyBadge({super.key});

  @override
  State<AutoApplyBadge> createState() => _AutoApplyBadgeState();
}

class _AutoApplyBadgeState extends State<AutoApplyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 🔲 Card background
        Container(
          height: 90,
          width: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1F24), blue_gray],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFF00FFF7),
                ),
                SizedBox(
                  height: 4,
                ),
                Text(
                  "Candidature auto",
                  style: TextStyle(
                    color: white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Ajouter plus",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ⚡️ Animated badge
        Positioned(
          top: -12,
          right: -12,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              height: 30,
              width: 30,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: black_gray),
              child: const Icon(
                Icons.add,
                size: 18,
                weight: 2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
