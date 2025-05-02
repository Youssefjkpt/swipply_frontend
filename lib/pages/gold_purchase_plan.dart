// ignore_for_file: unused_field
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:http/http.dart' as http;

class SwipplyGoldDetailsPage extends StatefulWidget {
  const SwipplyGoldDetailsPage({super.key});

  @override
  State<SwipplyGoldDetailsPage> createState() => _SwipplyGoldDetailsPageState();
}

class _SwipplyGoldDetailsPageState extends State<SwipplyGoldDetailsPage>
    with SingleTickerProviderStateMixin {
  int selectedPlanIndex = 1;
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  final List<String> stripePriceIds = [
    "price_1RAnPeCKzHpBcr4fcNh5YkBs", // 1 Week
    "price_1RAxKMCKzHpBcr4fuHhvhxZG", // 1 Month
    "price_1RAxMMCKzHpBcr4fiWV16Vmc", // 6 Months
  ];

  void showUploadPopup(BuildContext context, {String? errorMessage}) {
    final bool isError = errorMessage != null;
    void showSuccessCheckPopup(BuildContext context, TickerProvider vsync) {
      final AnimationController _checkmarkController = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 1200),
      )..forward();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _checkmarkController,
              builder: (_, __) => CustomPaint(
                painter: CheckMarkPainter(_checkmarkController),
              ),
            ),
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop(); // dismiss popup
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: isError ? 300 : 100,
              height: 100,
              decoration: BoxDecoration(
                color: blue_gray,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(horizontal: isError ? 16 : 0),
              child: Row(
                mainAxisAlignment: isError
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(4),
                    child: LoadingBars(),
                  ),
                  if (isError) const SizedBox(width: 12),
                  if (isError)
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  final List<String> planLabels = ["1 Week", "1 Month", "6 Months"];
  final List<double> planPrices = [8.99, 39.96, 99.76];
  final List<String> planBadges = ["Popular", "", "Best Value"];
  final List<String> planSubtexts = ["8.99 €/wk", "7.99 €/wk", "5.99 €/wk"];
  final List<String> savings = ["", "Save 40%", "Save 76%"];

  final List<Map<String, String>> features = [
    {
      "title": "Preference job selection",
      "description": "Choose job types that match your skills and interests."
    },
    {
      "title": "Filter by salary",
      "description":
          "Set salary thresholds and discover jobs that meet your expectations."
    },
    {
      "title": "1h AI auto-apply / day",
      "description": "Automatically apply to top job matches using advanced AI."
    },
    {
      "title": "Rewind likes/jobs",
      "description":
          "Go back and review previous job opportunities or liked roles."
    },
  ];

  Widget buildFeatureSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 30, bottom: 40),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: white_gray, width: 1),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: features.map((feature) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            feature['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Text(
                        feature['description']!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: white_gray, width: 1.4),
              ),
              child: const Text(
                "Included with Swipply Gold",
                style: TextStyle(
                  color: white_gray,
                  fontSize: 14,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void showSuccessCheckPopup(BuildContext context, TickerProvider vsync) {
    final AnimationController _checkmarkController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedBuilder(
            animation: _checkmarkController,
            builder: (_, __) => CustomPaint(
              painter: CheckMarkPainter(_checkmarkController),
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blue_gray,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: white,
                    size: 30,
                  ),
                ),
                const Expanded(child: SizedBox(width: 1)),
                const Text(
                  "Swipply",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 30),
                  child: Transform(
                    transform: Matrix4.skewX(-0.3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 229, 175, 51),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "GOLD",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox(width: 1)),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(children: [
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Instantly Unlock Premium features with Swipply Gold.",
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Select a plan",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.22,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: planLabels.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == selectedPlanIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedPlanIndex = index);
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFD97D)
                                  : white_gray,
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              if (planBadges[index].isNotEmpty)
                                Text(
                                  planBadges[index],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color.fromARGB(255, 255, 205, 88),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                planLabels[index],
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                              const Expanded(
                                  child: SizedBox(
                                height: 1,
                              )),
                              Row(
                                children: [
                                  Text(
                                    planSubtexts[index],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (savings[index].isNotEmpty)
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: blue_gray,
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          child: Text(
                                            savings[index],
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
                  child: buildFeatureSection(),
                )
              ]),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    "By tapping Continue, you will be charged. This is a one-time payment. No renewal.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Terms & Conditions | Privacy Policy",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final userId = await getUserId();
                final priceId = stripePriceIds[selectedPlanIndex];

                showUploadPopup(context); // 🟡 Show loading

                final uri = Uri.parse("$BASE_URL_JOBS/create-checkout-session");

                try {
                  final response = await http.post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'user_id': userId, 'priceId': priceId}),
                  );

                  Navigator.of(context).pop(); // ⛔ Remove loading

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    final checkoutUrl = data['url'];

                    final launched = await launchUrlString(
                      checkoutUrl,
                      mode: LaunchMode.externalApplication,
                    );

                    if (!launched) {
                      showUploadPopup(context,
                          errorMessage: "❌ Couldn't open Stripe link.");
                    }
                  } else {
                    showUploadPopup(context,
                        errorMessage: "❌ Stripe Error: ${response.body}");
                  }
                } catch (e) {
                  Navigator.of(context).pop(); // Remove loading
                  showUploadPopup(context, errorMessage: "❌ Exception: $e");
                }
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEEEC6), Color(0xFFFFD97D)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    "Continue for ${planPrices[selectedPlanIndex].toStringAsFixed(2)} € total",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class LoadingBars extends StatefulWidget {
  const LoadingBars({super.key});

  @override
  State<LoadingBars> createState() => _LoadingBarsState();
}

class _LoadingBarsState extends State<LoadingBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int barCount = 4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  double _barValue(double controllerValue, int index) {
    final delay = index * 0.15;
    final t = (controllerValue + delay) % 1.0;
    return TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(barCount, (i) {
              final scaleY = _barValue(_controller.value, i);
              return Transform.scale(
                scaleY: scaleY,
                child: Container(
                  width: 6,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          );
        },
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

    if (progress > 0.6) {
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
