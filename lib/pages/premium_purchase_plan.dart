import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/main_layout.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:http/http.dart' as http;

const Set<String> _kProductIds = {
  'Swipply_platinum_1week',
  'Swipply_platinum_1month',
  'Swipply_platinum_6month',
};

final List<String> _platinumIdsInOrder = [
  'Swipply_platinum_1week',
  'Swipply_platinum_1month',
  'Swipply_platinum_6month',
];
StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

class SwipplyPremiumDetailsPage extends StatefulWidget {
  const SwipplyPremiumDetailsPage({super.key});

  @override
  State<SwipplyPremiumDetailsPage> createState() =>
      _SwipplyPremiumDetailsPageState();
}

class _SwipplyPremiumDetailsPageState extends State<SwipplyPremiumDetailsPage> {
  final List<String> planLabels = ["1 semaine", "1 mois", "6 mois"];
// ─── 1) Replace your stripePriceIds with the correct Platinum IDs ─────────
  final List<String> stripePriceIds = [
    "price_1RWhzsCKzHpBcr4fEFtyaiX6", // Platinum 1 week (12.99 €)
    "price_1RWi22CKzHpBcr4fnln8iblK", // Platinum 1 month (24.99 €)
    "price_1RWi89CKzHpBcr4fdsvUIZd8", // Platinum 6 months (94.99 €)
  ];
  void _debugPrintProducts() {
    for (final p in _products) {
      dev.log('▶︎ StoreKit product: ${p.id}', name: 'PlatinumPage');
    }
  }

  bool _iapAvailable = false;
  bool _loading = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
// ─── 2) Replace your displayed prices ───────────────────────────────────────
  final List<double> planPrices = [12.99, 24.99, 94.99];

// ─── 3) Badges (1 week = “Populaire”, 1 month = “Économique”, 6 mois = “Meilleure offre”) ──
  final List<String> planBadges = [
    "Populaire",
    "Économique",
    "Meilleure offre",
  ];
  int? _sel;
// ─── 4) Sub-text showing €/week equivalents ────────────────────────────────
  final List<String> planSubtexts = [
    "12,99 € / sem.",
    "6,20 € / sem.", // 24.99 € ÷ 4 sem.
    "3,99 € / sem.", // 94.99 € ≃ 26 sem. ⇒ 3.99 € / sem.
  ];

// ─── 5) (Optional) Rough “savings” labels ──────────────────────────────────
  final List<String> savings = [
    "",
    "Écon. 52 %", // 24.99 vs (12.99 × 4≈51.96)
    "Écon. 70 %", // 94.99 vs (12.99 × 26≈337.74)
  ];

  void showUploadPopup(BuildContext context, {String? errorMessage}) {
    final bool isError = errorMessage != null;
    void showSuccessCheckPopup(BuildContext context, TickerProvider vsync) {
      final AnimationController checkmarkController = AnimationController(
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
              animation: checkmarkController,
              builder: (_, __) => CustomPaint(
                painter: CheckMarkPainter(checkmarkController),
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

  String plan = 'Platinum';
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  final List<Map<String, String>> features = [
    {
      "title": "Candidature automatique illimitée",
      "description":
          "Laissez notre IA postuler sans interruption pour maximiser vos chances.",
    },
    {
      "title": "Recommandations d'emploi prioritaires",
      "description": "Recevez les meilleures offres avant tout le monde.",
    },
    {
      "title": "Badge de profil vérifié",
      "description":
          "Distinguez-vous auprès des recruteurs grâce à un badge Platinum.",
    },
    {
      "title": "Messagerie directe recruteur",
      "description":
          "Contactez directement les recruteurs et soyez repéré plus vite.",
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
            border: Border.all(color: Colors.cyanAccent, width: 1.2),
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
                            color: Color(0xFF18FFFF), size: 24),
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
                border: Border.all(color: Colors.cyanAccent, width: 1.4),
              ),
              child: const Text(
                "Inclus avec Swipply Platinum",
                style: TextStyle(
                  color: Colors.cyanAccent,
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

  bool get _canContinue => _sel != null && !_loading;

  Future<String?> _uid() async =>
      (await SharedPreferences.getInstance()).getString('user_id');
  bool _celebratedThisSession = false;

// ─── IAP flow ────────────────────────────────────────────────────────────
  void _onPurchases(List<PurchaseDetails> pchs) async {
    for (final p in pchs) {
      if (p.status == PurchaseStatus.purchased) {
        // 🎉 brand-new
        if (_celebratedThisSession) continue;
        _celebratedThisSession = true;

        await _unlockPlatinum(); // save prefs etc.
        if (mounted) await showGoldCelebrationPopup(context);
      } else if (p.status == PurchaseStatus.restored) {
        // 🤫 silent unlock
        await _unlockPlatinum();
      } else if (p.status == PurchaseStatus.error && mounted) {
        showStripeErrorPopup(context);
      }

      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  /// keeps common unlock logic in one place
  Future<void> _unlockPlatinum() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plan_name', 'Platinum');
    await prefs.setString('swipe_date', '');
    await prefs.setInt('swipe_count', 0);
    await _fetchUserCapabilities();
  }

/* ────── product fetch ────── */
  Future<void> _fetchProducts() async {
    final resp = await InAppPurchase.instance.queryProductDetails(_kProductIds);
    dev.log('▶︎ notFoundIDs: ${resp.notFoundIDs}', name: 'PlatinumPage');
    dev.log('▶︎ productDetails.length: ${resp.productDetails.length}',
        name: 'PlatinumPage');
    if (resp.error != null) {
      dev.log(
          '▶︎ queryProductDetails ERROR: code=${resp.error!.code} '
          'message=${resp.error!.message}',
          name: 'PlatinumPage');
    }

    _products = resp.productDetails;
  }

  Future<void> _handleContinue() async {
    if (_sel == null) return;
    if (_products.isEmpty) {
      if (!_iapAvailable) return _showErr();
      setState(() => _loading = true);
      await _fetchProducts();
      setState(() => _loading = false);
      if (_products.isEmpty) return _showErr();
    }

    final pid = _platinumIdsInOrder[_sel!];
    final prod = _products.firstWhere((p) => p.id == pid);
    final param = PurchaseParam(productDetails: prod);

    setState(() => _loading = true);
    try {
      await InAppPurchase.instance.buyConsumable(
        purchaseParam: param,
        autoConsume: true,
      );
    } catch (_) {
      _showErr();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();

    // 1) Listen for incoming purchase updates
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) => dev.log('purchaseStream ERROR: $e'),
      onDone: () => _purchaseSub?.cancel(),
    );

    // 2) Ask StoreKit to resend any unfinished transactions
    InAppPurchase.instance.restorePurchases().then((_) {
      dev.log('🔄 restorePurchases() issued', name: 'PlatinumPage');
    });

    // 3) Finally, check IAP availability
    InAppPurchase.instance.isAvailable().then((ok) {
      setState(() => _iapAvailable = ok);
    });
  }

  Future<void> _flushStaleTransactions() async {
    await InAppPurchase.instance.restorePurchases();
    dev.log('🔄 restorePurchases() issued', name: 'PlatinumPage');
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      dev.log('🛎 purchase update for ${p.productID}: ${p.status}',
          name: 'PlatinumPage');

      // Always finish the transaction so StoreKit removes it from its queue
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored ||
          p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
        dev.log('✅ completePurchase() for ${p.productID}',
            name: 'PlatinumPage');
      }

      if (p.status == PurchaseStatus.error) {
        showStripeErrorPopup(context);
        continue;
      }

      // Show the celebration popup on PURCHASED or RESTORED
      final idx = _platinumIdsInOrder.indexOf(p.productID);
      if ((p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) &&
          idx != -1 &&
          mounted) {
        // You already have a hard-coded message in your Platinum popup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showGoldCelebrationPopup(context);
        });
      }
    }
  }

  Widget _buildContinueButton() {
    final isSelected = _sel != null;
    final isOwned = false; // consumables aren’t “owned” long-term
    final priceLabel = isSelected ? planPrices[_sel!].toStringAsFixed(2) : '';

    return GestureDetector(
      onTap: (isSelected && !_loading) ? _handleContinue : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: (isSelected && !_loading)
              ? const LinearGradient(colors: [Colors.cyanAccent, Colors.cyan])
              : null,
          color:
              (!isSelected || _loading) ? Colors.grey.withOpacity(.35) : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Text(
                  isSelected
                      ? "Continuer pour $priceLabel € total"
                      : "Sélectionnez une offre",
                  style: TextStyle(
                    color: (isSelected && !_loading)
                        ? Colors.black
                        : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
      ),
    );
  }

  // your existing `_unlockPlatinum`, `_showErr`, `_debugPrintProducts`, etc.

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  void _showErr() => showStripeErrorPopup(context);

  Future<void> _showCelebration() => showGoldCelebrationPopup(context);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: blue_gray,
        body: SafeArea(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.cyan,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "PLATINUM",
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
                "Optimisez votre recherche d'emploi avec Swipply Platinum.",
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
              height: MediaQuery.of(context).size.height * .22,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: planLabels.length,
                itemBuilder: (c, i) {
                  final sel = i == _sel;
                  return GestureDetector(
                    onTap: () => setState(() => _sel = i),
                    child: Container(
                      width: MediaQuery.of(context).size.width * .6,
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                            color: sel ? Colors.cyanAccent : white_gray,
                            width: sel ? 2.5 : 1.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          if (planBadges[i].isNotEmpty)
                            Text(planBadges[i],
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(planLabels[i],
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          sel ? Colors.white : Colors.white70)),
                              const Expanded(child: SizedBox()),
                              if (savings[i].isNotEmpty)
                                Container(
                                  decoration: BoxDecoration(
                                      color: blue_gray,
                                      borderRadius: BorderRadius.circular(100)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  child: Text(savings[i],
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: white,
                                          fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          const Expanded(child: SizedBox()),
                          Text(planSubtexts[i],
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white54)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
              child: buildFeatureSection(), // unchanged helper
            ),
          ])),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Text(
                      "En appuyant sur Continuer, vous serez débité. Paiement unique, sans renouvellement.",
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
                    _buildContinueButton(),
                  ]))
        ])));
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
    late final Timer autoCloseTimer;
    autoCloseTimer = Timer(const Duration(seconds: 7), () {
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
          cancelAutoClose: () => autoCloseTimer.cancel(), // ← REAL canceller
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
  const _StripeErrorContent({super.key});

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
    Future.delayed(const Duration(seconds: 2)).then((_) {
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
                              gdiamond,
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
                        color: white,
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
                      "Votre adhésion Platinum est maintenant activée.",
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
                          color: Color(0xFF18FFFF),
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
