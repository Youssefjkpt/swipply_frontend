import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/subscriptions.dart';

class SuperLikeBadge extends StatefulWidget {
  const SuperLikeBadge({super.key});

  @override
  State<SuperLikeBadge> createState() => _SuperLikeBadgeState();
}

class _SuperLikeBadgeState extends State<SuperLikeBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
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
        // Main glowing card
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => FullSubscriptionPage())),
          child: Container(
            height: 90,
            width: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  //Color(0xFF3A0D0D), Color(0xFF8E0000)
                  blue_gray, blue_gray
                  //Color(0xFF3A0D0D), Color(0xFF8E0000)
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_rounded,
                      color: Color(0xFFFF5C5C), size: 20),
                  SizedBox(height: 6),
                  Text(
                    "Mes likes",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
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
        ),

        // Animated Badge top-right
        Positioned(
          top: -12,
          right: -12,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              height: 28,
              width: 28,
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
