// lib/screens/gold_celebration_screen.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:swipply/constants/images.dart';
import 'package:vibration/vibration.dart';

class GoldCelebrationScreen extends StatefulWidget {
  final String firstName; // optional user name, pass from previous screen

  const GoldCelebrationScreen({super.key, this.firstName = ''});

  @override
  State<GoldCelebrationScreen> createState() => _GoldCelebrationScreenState();
}

class _GoldCelebrationScreenState extends State<GoldCelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final AnimationController _cardsController;
  late final AnimationController _ribbonController;
  late final AnimationController _avatarController;
  late final Animation<double> _avatarAnimation;

  @override
  void initState() {
    super.initState();

    // 1) Badge pops at t = 0.0 → 0.8s
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 2) Cards flip in sequence, 3 cards each 0.4s, total 1.2s
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 3) Ribbon unfurls at t = 0.0 → 0.8s (after cards)
    _ribbonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 4) Avatar float: loops a gentle up/down
    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _avatarAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _avatarController, curve: Curves.easeInOut),
    );

    // Start the entire sequence after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playSequence();
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _cardsController.dispose();
    _ribbonController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _playSequence() async {
    // 1) Badge
    _badgeController.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    // 2) Haptic + Confetti (via Lottie on next screen) – trigger vibration
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }
    _cardsController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));

    // 3) Ribbon
    _ribbonController.forward();
    // Now let next‐steps appear (no extra wait)
  }

  Widget _buildBadge() {
    return Lottie.asset(
      goldBadge,
      controller: _badgeController,
      onLoaded: (composition) {
        _badgeController.duration = composition.duration;
      },
      width: 120,
      height: 120,
    );
  }

  Widget _buildCards() {
    // Three cards side by side. Each “flip” starts at 0.0, 0.2, 0.4 in _cardsController
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (i) {
        final start = i * 0.2;
        final end = start + 0.2;
        final animation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            // At t < 0.5 → front (grey lock); at t > 0.5 → back (gold check)
            final isBack = animation.value > 0.5;
            final tweenValue = (animation.value <= 0.5)
                ? animation.value * 2
                : (animation.value - 0.5) * 2;
            final angle = tweenValue * 3.14159; // 0 → π

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: isBack ? Colors.amberAccent : Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Icon(
                    isBack ? Icons.check_circle : Icons.lock,
                    color: isBack ? Colors.white : Colors.white30,
                    size: 32,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildConfetti() {
    // plays behind the badge (short 1s animation). Start when badge completes.
    return Lottie.asset(
      confetti,
      repeat: false,
      width: 200,
      height: 200,
    );
  }

  Widget _buildRibbon() {
    return Lottie.asset(
      ribbon,
      controller: _ribbonController,
      onLoaded: (composition) {
        _ribbonController.duration = composition.duration;
      },
      width: 250,
      height: 80,
    );
  }

  Widget _buildAvatar() {
    // floating circle with user’s initial
    return AnimatedBuilder(
      animation: _avatarAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_avatarAnimation.value),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.amberAccent,
            child: Text(
              widget.firstName.isNotEmpty
                  ? widget.firstName[0].toUpperCase()
                  : 'G',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextSteps() {
    // Simple checklist under the ribbon/avatar
    final steps = [
      'Complete your profile',
      'Unlock your first perk',
      'Explore premium features'
    ];
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: Icon(Icons.check_circle_outline, color: Colors.white70),
          title: Text(
            steps[i],
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          onTap: () {
            // Add your navigation for each step, e.g.:
            // if (i == 0) Navigator.pushNamed(context, '/profile');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // white/light background so animations pop
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // 2a) Title
            const Text(
              '🎉 Congratulations, you’re now Gold!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // 2b) Badge pop
            Center(child: _buildBadge()),

            // 2c) Confetti (overlay behind badge)
            Positioned(
              top: 80,
              left: (MediaQuery.of(context).size.width - 200) / 2,
              child: _buildConfetti(),
            ),

            const SizedBox(height: 8),

            // 2d) Cards flip
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildCards(),
            ),

            const SizedBox(height: 8),

            // 2e) Ribbon unfurl
            _buildRibbon(),

            // 2f) Floating avatar
            const SizedBox(height: 8),
            _buildAvatar(),

            const SizedBox(height: 16),

            // 2g) Next steps checklist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildNextSteps(),
            ),

            const Spacer(),

            // 2h) “Get Started” button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD97D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  // or push to your main dashboard: Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text(
                  'Let’s Get Started',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
