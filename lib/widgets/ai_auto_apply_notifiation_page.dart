import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

/// GODLIKE AI service card – simple border, pulsating button border, clean main container.
class AIApplicationServiceCard extends StatefulWidget {
  final VoidCallback onActivate;
  const AIApplicationServiceCard({super.key, required this.onActivate});

  @override
  _AIApplicationServiceCardState createState() =>
      _AIApplicationServiceCardState();
}

class _AIApplicationServiceCardState extends State<AIApplicationServiceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _borderController,
        builder: (context, child) {
          final t = _borderController.value;
          final color = Color.lerp(
            const Color(0xFF8E2DE2),
            const Color(0xFF00C6FF),
            t,
          )!
              .withOpacity(1);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 30,
                  color: white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Candidature IA',
                        style: TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Optimisez vos candidatures en un clic avec notre IA.',
                        style: TextStyle(
                            color: white_gray,
                            fontSize: 12,
                            fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 30,
                    ),
                    AnimatedBuilder(
                      animation: _borderController,
                      builder: (context, child) {
                        final t = _borderController.value;
                        final color = Color.lerp(
                          const Color(0xFF8E2DE2),
                          const Color(0xFF00C6FF),
                          t,
                        )!
                            .withOpacity(1);
                        return GestureDetector(
                          onTap: widget.onActivate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color, width: 2),
                            ),
                            child: const Text(
                              'Activer IA',
                              style: TextStyle(
                                color: white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        });
  }
}
