import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/main_layout.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:http/http.dart' as http;

class SwipplyPremiumDetailsPage extends StatefulWidget {
  const SwipplyPremiumDetailsPage({super.key});

  @override
  State<SwipplyPremiumDetailsPage> createState() =>
      _SwipplyPremiumDetailsPageState();
}

class _SwipplyPremiumDetailsPageState extends State<SwipplyPremiumDetailsPage> {
  int selectedPlanIndex = 1;

  final List<String> planLabels = ["1 semaine", "1 mois", "6 mois"];
  final List<double> planPrices = [12.99, 24.99, 94.99];
  final List<String> planBadges = [
    "Populaire",
    "Économique",
    "Meilleure offre"
  ];
  final List<String> planSubtexts = [
    "12,99 € / sem.",
    "6,20 € / sem.",
    "3,99 € / sem."
  ];
  final List<String> savings = ["", "Écon. 52 %", "Écon. 70 %"];

  bool _loading = false;

// ✅ Play Billing core
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  List<GooglePlayProductDetails> _gpProducts = [];
  final Map<String, Map<String, GooglePlayProductDetails>> _offerMap = {};

// ✅ Product IDs
  final String _platinumProductId = 'swipply_platinum';
// With this (order must match your UI cards):
  final List<String> _basePlanByIndex = [
    'swipply-platinum-week',
    'swipply-platinum-month',
    'swipply-platinum-6month',
  ];

// ✅ User state
  int? _personalizeLimit;
  int? _swipeLimit;
  bool _canPersonalize = false;
  String plan = 'Platinum';

// ─── 4) Sub-text showing €/week equivalents ────────────────────────────────

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

// 3) Fix the helper that builds the offers map (it referenced the wrong variable)
  Future<Map<String, Map<String, GooglePlayProductDetails>>>
      loadProductsAndOffers() async {
    final ids = {
      _platinumProductId,
    };
    final resp = await _iap.queryProductDetails(ids);
    final products =
        resp.productDetails.whereType<GooglePlayProductDetails>().toList();

    final map = <String, Map<String, GooglePlayProductDetails>>{};
    for (final p in products) {
      final offers = p.productDetails.subscriptionOfferDetails ?? [];
      for (final o in offers) {
        map.putIfAbsent(p.id, () => {});
        map[p.id]![o.basePlanId] = p;
      }
    }
    return map;
  }

  bool hasOfferFor(String productId, String basePlanId,
      Map<String, Map<String, GooglePlayProductDetails>> offerMap) {
    final product = offerMap[productId]?[basePlanId];
    if (product == null) return false;
    final offers = product.productDetails.subscriptionOfferDetails ?? [];

    return offers.any((o) =>
        o.basePlanId == basePlanId && (o.offerIdToken?.isNotEmpty ?? false));
  } // ✅ Safely find an active offer for a basePlanId

  // 2) Make offer lookup robust and noisy
  SubscriptionOfferDetailsWrapper? _findOfferFor(
    GooglePlayProductDetails product,
    String basePlanId,
  ) {
    final offers = product.productDetails.subscriptionOfferDetails ?? [];
    for (final o in offers) {
      final hasToken = (o.offerIdToken?.isNotEmpty ?? false);
      if (o.basePlanId == basePlanId && hasToken) return o;
    }
    return null;
  }

  // 6) Also harden the shared onContinueTap() you wrote so it logs similarly
  Future<void> onContinueTap({
    required String productId,
    required String basePlanId,
    required Map<String, Map<String, GooglePlayProductDetails>> offerMap,
  }) async {
    debugPrint('[BUY2] productId=$productId basePlanId=$basePlanId');
    final product = offerMap[productId]?[basePlanId];
    if (product == null) {
      debugPrint('[BUY2] no product for basePlanId=$basePlanId');
      showUploadPopup(context,
          errorMessage:
              "Offre indisponible pour ce plan. Réessayez dans quelques minutes.");
      return;
    }

    final gp = product as GooglePlayProductDetails;
    final offer = _findOfferFor(gp, basePlanId);
    if (offer == null) {
      debugPrint(
          '[BUY2] no offer token for basePlanId=$basePlanId product=${gp.id}');
      showUploadPopup(context,
          errorMessage:
              "Aucune offre active pour ce plan. Vérifiez vos paramètres Play Console.");
      return;
    }

    try {
      setState(() => _loading = true);
      debugPrint(
          '[BUY2] buyNonConsumable offerToken len=${offer.offerIdToken?.length}');
      final param = GooglePlayPurchaseParam(
        productDetails: gp,
        offerToken: offer.offerIdToken!,
      );
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('[BUY2] exception: $e');
      showStripeErrorPopup(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased) {
        await _iap.completePurchase(p);

        final prefs = await SharedPreferences.getInstance();
        final isPlatinum = p.productID == _platinumProductId;
        await prefs.setString('plan_name', isPlatinum ? 'Platinum' : 'Gold');
        await prefs.setString('swipe_date', '');
        await prefs.setInt('swipe_count', 0);

        await _fetchUserCapabilities();
        await showGoldCelebrationPopup(context);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else if (p.status == PurchaseStatus.error) {
        final msg = [
          if (p.error?.message != null) "Message: ${p.error!.message}",
          if (p.error?.details != null) "Details: ${p.error!.details}",
        ].where((e) => e.isNotEmpty).join("\n");
        _showIapError("Échec de l’achat.\n$msg");
      } else if (p.status == PurchaseStatus.canceled) {
        _showIapError("Achat annulé par l’utilisateur.");
      }
    }
  }

  // 4) Beef up _initBilling with diagnostics
  Future<void> _initBilling() async {
    debugPrint('[IAP] init start');
    final available = await _iap.isAvailable();
    debugPrint('[IAP] isAvailable=$available');
    if (!available) {
      _showIapError("Google Play indisponible sur cet appareil/compte.");
      return;
    }

    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchases, onError: (err) {
      debugPrint('[IAP] purchaseStream error: $err');
      _showIapError("Flux d’achats en erreur: $err");
    });

    final resp = await _iap.queryProductDetails({
      _platinumProductId,
    });
    debugPrint(
        '[IAP] notFoundIDs=${resp.notFoundIDs} count=${resp.productDetails.length}');
    if (resp.notFoundIDs.isNotEmpty) {
      _showIapError("Produit introuvable: ${resp.notFoundIDs.join(", ")}.\n"
          "• Installe depuis la piste de test\n"
          "• Ajoute un compte testeur\n"
          "• Vérifie base plans & propagation.");
      return;
    }

    _gpProducts =
        resp.productDetails.whereType<GooglePlayProductDetails>().toList();
    if (_gpProducts.isEmpty) {
      _showIapError("Aucun productDetails chargé. Propagation 5–30 min.");
      return;
    }

    _offerMap.clear();
    for (final p in _gpProducts) {
      final offers = p.productDetails.subscriptionOfferDetails ?? [];
      debugPrint('[IAP] product=${p.id} offers=${offers.length}');
      for (final o in offers) {
        debugPrint(
            '[IAP]  basePlanId=${o.basePlanId} hasToken=${o.offerIdToken?.isNotEmpty == true}');
        _offerMap.putIfAbsent(p.id, () => {});
        _offerMap[p.id]![o.basePlanId] = p;
      }
    }

    if (mounted) setState(() {});
    debugPrint(
        '[IAP] init done. products=${_gpProducts.map((e) => e.id).toList()}');
  }

  void _showIapError(String message) {
    showGeneralDialog(
      context: context,
      barrierLabel: "iapError",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => SafeArea(
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.80,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: blue_gray,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45, blurRadius: 12, offset: Offset(0, 6))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Achat impossible",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none)),
                const SizedBox(height: 10),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        decoration: TextDecoration.none)),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text("Fermer",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            decoration: TextDecoration.none)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (_, a1, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
          child: child),
    );
  }

  @override
  void initState() {
    super.initState();
    _initBilling(); // important
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  final List<Map<String, String>> features = [
    {
      "title": "Swipes",
      "description":
          "80 swipes, recharge automatique, maximisez vos chances d’être embauché grâce à davantage d’offres et de candidatures pertinentes.",
    },
    {
      "title": "Candidature automatique IA",
      "description":
          "Laissez l'IA postuler pour vous, automatiquement pour maximiser vos chances.",
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
      "title": "Annuler likes/offres",
      "description": "Rétablissez les swipes effectués par erreur."
    },
    {
      "title": "Aucune publicité",
      "description": "Profitez d'une expérience fluide, sans interruption."
    },
    {
      "title": "Meilleures offres pour vous",
      "description":
          "Découvrez les emplois correspondant le mieux à votre profil."
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
                    "Je maximisez ma recherche d'emploi avec Swipply Platinum.",
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
                              color:
                                  isSelected ? Colors.cyanAccent : white_gray,
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              if (planBadges[index].isNotEmpty)
                                Text(
                                  planBadges[index],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.cyanAccent,
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
                              const Expanded(child: SizedBox(height: 1)),
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
                ],
              ),
            ),
            GestureDetector(
              // 5) Make the "Continuer" handler bulletproof and logged
              onTap: () async {
                final userId = await getUserId();
                if (userId == null) {
                  _showIapError("Utilisateur non identifié.");
                  return;
                }

                final String productId = _platinumProductId;
                final String basePlanId = _basePlanByIndex[selectedPlanIndex];

                debugPrint('[BUY] productId=$productId basePlanId=$basePlanId');

                final p = _offerMap[productId]?[basePlanId];
                if (p == null) {
                  debugPrint(
                      '[BUY] no product mapped for basePlanId=$basePlanId. keys=${_offerMap[productId]?.keys.toList()}');
                  _showIapError(
                      "Offre indisponible pour ce plan. Vérifie la console Play.");
                  return;
                }

                final offer = _findOfferFor(p, basePlanId);
                if (offer == null) {
                  debugPrint(
                      '[BUY] no active offer token for basePlanId=$basePlanId product=${p.id}');
                  _showIapError("Aucune offre active pour $basePlanId.");
                  return;
                }

                setState(() => _loading = true);
                try {
                  debugPrint(
                      '[BUY] calling buyNonConsumable with offerToken len=${offer.offerIdToken?.length}');
                  final param = GooglePlayPurchaseParam(
                    productDetails: p,
                    offerToken: offer.offerIdToken!,
                    applicationUserName: userId,
                  );
                  await _iap.buyNonConsumable(purchaseParam: param);
                } catch (e) {
                  debugPrint('[BUY] exception: $e');
                  _showIapError("Erreur d’achat: $e");
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },

              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: Text(
                          "Continuer pour ${planPrices[selectedPlanIndex].toStringAsFixed(2)} € au total",
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
