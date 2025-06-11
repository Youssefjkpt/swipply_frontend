// ignore_for_file: unused_field
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/main_layout.dart';

import 'package:http/http.dart' as http;

class SwipplyGoldDetailsPage extends StatefulWidget {
  const SwipplyGoldDetailsPage({super.key});

  @override
  State<SwipplyGoldDetailsPage> createState() => _SwipplyGoldDetailsPageState();
}

class _SwipplyGoldDetailsPageState extends State<SwipplyGoldDetailsPage>
    with TickerProviderStateMixin {
  // ✅ New fields:
  late final AnimationController _badgeController;
  late Animation<double> _badgeAngle;

  int selectedPlanIndex = 1;
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  final String plan = 'Gold';
  final List<String> stripePriceIds = [
    "price_1RWi4jCKzHpBcr4fu6S7WEZl", // Gold 1 week (8.99 €)
    "price_1RWi5FCKzHpBcr4frzSI5jOh", // Gold 1 month (17.99 €)
    "price_1RWi3vCKzHpBcr4fIcPiTSHP", // Gold 6 months (84.99 €)
  ];
  bool _showCelebration = false;

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

  final List<String> planLabels = ["1 semaine", "1 mois", "6 mois"];
  final List<double> planPrices = [8.99, 17.99, 84.99];
  final List<String> planBadges = [
    "Populaire",
    "Économique",
    "Meilleure offre"
  ];
  final List<String> planSubtexts = [
    "8.99 € / semaine",
    "4.5 € / semaine",
    "3.5 € / semaine"
  ];
  final List<String> savings = ["", "Écon. 50%", "Écon. 61%"];

  final List<Map<String, String>> features = [
    {
      "title": "Préférence de type d'emploi",
      "description":
          "Choisissez les types d'emploi correspondant à vos compétences et intérêts.",
    },
    {
      "title": "Filtrer par salaire",
      "description":
          "Fixez un seuil salarial et découvrez les offres qui répondent à vos attentes.",
    },
    {
      "title": "Candidature automatique IA 1h/jour",
      "description":
          "Postulez automatiquement aux meilleures offres grâce à l'IA avancée.",
    },
    {
      "title": "Annuler likes/offres",
      "description":
          "Revenez en arrière pour revoir les opportunités ou offres aimées.",
    },
  ];
  Timer? _autoDismissTimer;
  bool _homeButtonEnabled = false;
  Timer? _enableButtonTimer;

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
                "Inclus avec Swipply Gold",
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

    // 1) Run a continuous 0→2π animation over 600 ms:
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // 2) Map that to an angle in radians:
    _badgeAngle = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(_badgeController);
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blue_gray,
      body: Stack(
        children: [
          SafeArea(
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
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(children: [
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Débloquez instantanément les fonctionnalités Gold.",
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
                        "Sélectionnez une offre",
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
                                        color:
                                            Color.fromARGB(255, 255, 205, 88),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
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
                                      Expanded(
                                          child: SizedBox(
                                        width: 1,
                                      )),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
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
                      padding:
                          const EdgeInsets.only(left: 15, right: 15, top: 20),
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
                        "En appuyant sur Continuer, vous serez facturé. Paiement unique, sans renouvellement.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Conditions générales | Politique de confidentialité",
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.1,
                          color: Colors.white54,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final userId = prefs.getString('user_id');
                    print('🔥 onTap start; userId=$userId');
                    if (userId == null) {
                      print('⚠️ no userId, aborting');
                      showStripeErrorPopup(context);
                      return;
                    }
                    setState(() => _loading = true);
                    try {
                      final priceId = stripePriceIds[selectedPlanIndex];
                      print('📦 creating PaymentIntent for priceId=$priceId');
                      final uri =
                          Uri.parse('$BASE_URL_JOBS/create-payment-intent');
                      final response = await http.post(
                        uri,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(
                            {'user_id': userId, 'price_id': priceId}),
                      );
                      print('📡 create-intent status=${response.statusCode}');
                      print('📨 body=${response.body}');
                      if (response.statusCode != 200) {
                        throw Exception('HTTP ${response.statusCode}');
                      }
                      final body = jsonDecode(response.body);
                      final clientSecret = body['clientSecret'] as String;
                      print('🔑 clientSecret=$clientSecret');
                      await Stripe.instance.initPaymentSheet(
                        paymentSheetParameters: SetupPaymentSheetParameters(
                          paymentIntentClientSecret: clientSecret,
                          merchantDisplayName: 'Swipply',
                        ),
                      );
                      print('✅ initPaymentSheet done');
                      await Stripe.instance.presentPaymentSheet();
                      print('🎉 presentPaymentSheet done');
                      await prefs.setString('plan_name', 'Gold');
                      print('💾 prefs updated, navigating home');
                      await showGoldCelebrationPopup(context);
                      Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => MainLayout()));
                    } catch (e, st) {
                      print('❌ payment flow error: $e');
                      print(st);
                      showStripeErrorPopup(context);
                    } finally {
                      setState(() => _loading = false);
                      print('🔚 onTap end');
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
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Center(
                            child: Text(
                              "Continuer pour ${planPrices[selectedPlanIndex].toStringAsFixed(2)} € total",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUserCapabilities() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');
    if (userId == null) return;

    final res = await http.get(
      Uri.parse('$BASE_URL_AUTH/api/user-capabilities/$userId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        _swipeLimit = data['daily_swipe_limit'];
        _canPersonalize = data['can_personalize_cv'];
        _personalizeLimit = data['daily_personalize_limit'];
      });
    }
  }

  int? _personalizeLimit;
  int? _swipeLimit;
  bool _canPersonalize = false;

  /// Show a centered blue-gray dialog that reports a Stripe failure.
  /// [errorMsg] → line of text shown under the sad-emoji animation.
  /// Friendly, generic Stripe–error dialog (no raw backend text shown)
  void showStripeErrorPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "stripeError",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SafeArea(
        child: _StripeErrorContent(), // ← no parameter anymore
      ),
      transitionBuilder: (_, a1, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
          child: child),
    );
  }

  /// 1) In your SwipplyGoldDetailsPage class:
  Future<void> showGoldCelebrationPopup(BuildContext context) {
    // A) create the timer and keep a handle to it
    late final Timer _autoCloseTimer;
    _autoCloseTimer = Timer(const Duration(seconds: 7), () {
      final nav = Navigator.maybeOf(context);
      if (nav != null && nav.canPop()) nav.pop();
    });

    // B) show the dialog and give it a way to cancel the timer
    return showGeneralDialog(
      context: context,
      barrierLabel: "goldCelebration",
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) => SafeArea(
        child: _GoldCelebrationContent(
          originalContext: context,
          cancelAutoClose: () => _autoCloseTimer.cancel(), // ← REAL canceller
        ),
      ),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}

class _StripeErrorContent extends StatelessWidget {
  const _StripeErrorContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext ctx) {
    return Center(
      child: Container(
        width: MediaQuery.of(ctx).size.width * 0.80,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1) Bigger Lottie (fits width while respecting aspect ratio)
            SizedBox(
              height: 130, // ← adjust to any size you want
              width: 130,
              child: Lottie.asset(
                errorBox, // your asset constant / path
                fit: BoxFit.contain,
              ),
            ),

            // 2) Friendly headline
            const Text(
              "Oups ! Paiement échoué",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: null,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),

            // 3) Short explanatory sentence – always the same
            const Text(
              "Merci de réessayer ou d’utiliser un autre moyen de paiement.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontFamily: null,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 28),

            // 4) Close button
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Fermer",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: null,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 20,
            )
          ],
        ),
      ),
    );
  }
}

/// 2) The inner StatefulWidget that displays badge/confetti & button:
class _GoldCelebrationContent extends StatefulWidget {
  final BuildContext originalContext;
  final VoidCallback cancelAutoClose;
  const _GoldCelebrationContent({
    required this.originalContext,
    required this.cancelAutoClose,
  });

  @override
  State<_GoldCelebrationContent> createState() =>
      _GoldCelebrationContentState();
}

class _GoldCelebrationContentState extends State<_GoldCelebrationContent>
    with TickerProviderStateMixin {
  late final AnimationController _badgeController;
  late Animation<double> _badgeAngle;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();

    // 1) Run a continuous 0→2π animation over 5000 ms:
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    // 2) Map that to an angle in radians:
    _badgeAngle = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(_badgeController);

    // 3) Schedule enabling the cancel‐icon after 4 seconds:
    Future.delayed(const Duration(seconds: 4)).then((_) {
      if (mounted) {
        setState(() {
          _canClose = true;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.cancelAutoClose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext dialogCtx) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1) Confetti Lottie (behind entire screen)
        Positioned.fill(
          child: Stack(
            children: [
              // First confetti immediately:
              Positioned.fill(
                child: Lottie.asset(
                  confetti,
                  fit: BoxFit.cover,
                  repeat: false,
                ),
              ),
              // Second confetti after 1 second:
              Positioned.fill(
                child: FutureBuilder<void>(
                  future: Future.delayed(const Duration(seconds: 1)),
                  builder: (ctx2, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Lottie.asset(
                        confetti,
                        fit: BoxFit.cover,
                        repeat: false,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),

        // 2) Center Card‐like container with semi‐transparent blue_gray background
        Center(
          child: Container(
            width: MediaQuery.of(dialogCtx).size.width * 0.80,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: blue_gray.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
              border: Border.all(color: Colors.grey.shade800, width: 1.2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // A) Confetti fills the entire card background:
                Positioned.fill(
                  child: Lottie.asset(
                    confetti,
                    fit: BoxFit.cover,
                    repeat: false,
                  ),
                ),

                // B) The column of badge + texts + “Aller à l’accueil” button:
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1) Floating gold badge:
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _badgeAngle,
                          builder: (context, child) {
                            final t = _badgeAngle.value;
                            // Horizontal amplitude ±5% of width:
                            final dx = 0.05 * sin(t);
                            // Vertical amplitude ±4.5% of height:
                            final dy = 0.045 * sin(2 * t);
                            return FractionalTranslation(
                              translation: Offset(dx, dy),
                              child: child,
                            );
                          },
                          child: SizedBox(
                            height: 100,
                            width: 100,
                            child: Lottie.asset(
                              goldBadge,
                              repeat: false,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // 2) “Félicitations!” title:
                    const Text(
                      "Félicitations!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 4,
                            color: Colors.black54,
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 3) “Votre adhésion Gold …” subtitle:
                    const Text(
                      "Votre adhésion Gold est maintenant activée.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 4) “Aller à l’accueil” button (in French):
                    // ─── REPLACE THIS ENTIRE GestureDetector(...) BLOCK ───────────────────────────
                    // 4) “Aller à l’accueil” button (in French):
                    GestureDetector(
                      onTap: () {
                        widget.cancelAutoClose();
                        // 1) Dismiss the celebration dialog first:
                        Navigator.of(dialogCtx).pop();

                        // 2) After the dialog closes, safely navigate to home:
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final nav = Navigator.maybeOf(dialogCtx);
                          if (nav != null) {
                            nav.pushReplacement(
                              MaterialPageRoute(builder: (_) => MainLayout()),
                            );
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Aller à l’accueil",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),

// ───────────────────────────────────────────────────────────────────────────

                    const SizedBox(height: 12),
                  ],
                ),

                // C) Top‐right Cancel “X” icon:
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: _canClose ? Colors.white : Colors.grey,
                      size: 24,
                    ),
                    onPressed: _canClose
                        ? () {
                            widget.cancelAutoClose();
                            Navigator.of(dialogCtx).pop();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
