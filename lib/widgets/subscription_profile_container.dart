import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

class SubscriptionBadge extends StatefulWidget {
  const SubscriptionBadge({super.key});

  @override
  State<SubscriptionBadge> createState() => _SubscriptionBadgeState();
}

class _SubscriptionBadgeState extends State<SubscriptionBadge>
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
        Container(
          height: 90,
          width: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [blue_gray, Color(0xFF1C1C1C)],
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
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD700),
                ),
                SizedBox(
                  height: 4,
                ),
                Padding(
                  padding: EdgeInsets.only(left: 2, right: 2),
                  child: Text(
                    "Subscriptions",
                    style: TextStyle(
                      color: white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Add more",
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

        // 👑 Badge icon
        Positioned(
          top: -12,
          right: -12,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              height: 30,
              width: 30,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: black_gray),
              child: const Icon(
                Icons.add,
                size: 18,
                color: white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
