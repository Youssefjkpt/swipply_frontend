import 'dart:async';
import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/gold_purchase_plan.dart';
import 'package:swipply/pages/premium_purchase_plan.dart';
import 'package:swipply/pages/subscriptions.dart';
import 'package:swipply/widgets/golden_plan.dart';
import 'package:swipply/widgets/subscriptions_profile.dart';

class MiniSubscriptionSwiper extends StatefulWidget {
  const MiniSubscriptionSwiper({super.key});

  @override
  State<MiniSubscriptionSwiper> createState() => _MiniSubscriptionSwiperState();
}

class _MiniSubscriptionSwiperState extends State<MiniSubscriptionSwiper> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _currentPage = 0;
  Timer? _autoSwipeTimer;
  Timer? _pauseTimer;

  final List<String> liteFeatures = [
    "Sélection de poste préférée",
    "1 h de candidature automatique IA/jour",
  ];
  final List<bool> liteFree = [true, false];
  final List<bool> liteGold = [true, true];
  final List<bool> litePlatinum = [true, true];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoSwipe(); // Ensure the timer starts after layout
    });
  }

  void _startAutoSwipe() {
    _autoSwipeTimer?.cancel();
    _autoSwipeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_controller.hasClients) return;

      int nextPage = (_currentPage + 1) % 3;

      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      setState(() {
        _currentPage = nextPage;
      });
    });
  }

  void _pauseAutoSwipe() {
    _autoSwipeTimer?.cancel();
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 2), _startAutoSwipe);
  }

  @override
  void dispose() {
    _autoSwipeTimer?.cancel();
    _pauseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ⏩ Swipeable cards
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: PageView.builder(
            controller: _controller,
            itemCount: 3,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _pauseAutoSwipe(); // ⏸ Pause auto-swipe on manual swipe
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => FullSubscriptionPage())),
                  child: SubscriptionComparisonCard(
                    planName: "Swipply",
                    badgeText: "GRATUIT",
                    gradientStart: blue_gray,
                    gradientEnd: black_gray,
                    features: liteFeatures,
                    includedInFree: liteFree,
                    includedInPlan: liteFree,
                  ),
                );
              } else if (index == 1) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SwipplyGoldDetailsPage())),
                  child: GoldSubscriptionCard(
                    features: liteFeatures,
                    includedInFree: liteFree,
                    includedInGold: liteGold,
                    includedInPlan: [],
                  ),
                );
              } else {
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SwipplyPremiumDetailsPage())),
                  child: PlatinumSubscriptionCard(
                    features: liteFeatures,
                    includedInFree: liteFree,
                    includedInGold: liteGold,
                    includedInPlatinum: litePlatinum,
                  ),
                );
              }
            },
          ),
        ), // 🔘 Circle indicators
      ],
    );
  }
}
