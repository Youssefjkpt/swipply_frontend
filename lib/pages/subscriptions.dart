import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/gold_purchase_plan.dart';
import 'package:swipply/pages/premium_purchase_plan.dart';

class FullSubscriptionPage extends StatefulWidget {
  const FullSubscriptionPage({super.key});

  @override
  State<FullSubscriptionPage> createState() => _FullSubscriptionPageState();
}

class _FullSubscriptionPageState extends State<FullSubscriptionPage> {
  int _currentPage = 0;
  final PageController _topController = PageController(viewportFraction: 0.85);

  final List<Map<String, String>> features = [
    {
      "title": "Préférence de type d'emploi",
      "description":
          "Choisissez les catégories d'emploi que vous souhaitez voir en priorité.",
    },
    {
      "title": "Filtrer par salaire",
      "description":
          "Consultez uniquement les offres au-dessus de la rémunération souhaitée.",
    },
    {
      "title": "Candidature automatique IA 1h/jour",
      "description":
          "Laissez l'IA postuler automatiquement pendant 1 heure chaque jour.",
    },
    {
      "title": "Annuler likes/offres",
      "description": "Rétablissez les swipes effectués par erreur.",
    },
    {
      "title": "Candidatures prioritaires",
      "description": "Votre profil sera mieux classé auprès des recruteurs.",
    },
    {
      "title": "Aucune publicité",
      "description": "Profitez d'une expérience fluide, sans interruption.",
    },
    {
      "title": "Meilleures offres pour vous",
      "description":
          "Découvrez les emplois correspondant le mieux à votre profil.",
    },
  ];

  final List<bool> includedInFree = [
    true,
    false,
    false,
    false,
    false,
    false,
    false
  ];
  final List<bool> includedInGold = [
    true,
    true,
    true,
    true,
    false,
    false,
    false
  ];
  final List<bool> includedInPlatinum = [
    true,
    true,
    true,
    true,
    true,
    true,
    true
  ];

  final Map<String, List<int>> featureSections = {
    "Essentiels": [0, 1],
    "Améliorez votre expérience": [2, 3],
    "Passez Pro": [4, 5, 6],
  };

  Widget buildSection(String title, List<int> indexes, List<bool> included) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 28, bottom: 30),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1),
            borderRadius: BorderRadius.circular(22),
            color: Colors.black,
          ),
          child: Column(
            children: indexes.map((i) {
              bool isLocked = !included[i];
              final feature = features[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLocked ? Icons.lock_outline : Icons.check_circle,
                          color: isLocked ? Colors.white24 : Colors.greenAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature["title"]!,
                            style: TextStyle(
                              fontSize: 15,
                              color: isLocked ? Colors.white38 : Colors.white,
                              fontWeight:
                                  isLocked ? FontWeight.w400 : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (feature["description"] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, top: 6),
                        child: Text(
                          feature["description"]!,
                          style: TextStyle(
                            color: isLocked ? Colors.white24 : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      )
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPlanCard(String title, bool isPlatinum, List<bool> included) {
    IconData icon;
    Color iconColor;
    String label;

    if (title.toLowerCase().contains("premium")) {
      icon = Icons.diamond;
      iconColor = Colors.cyanAccent;
      label = "PREMIUM";
    } else if (title.toLowerCase().contains("gold")) {
      icon = Icons.emoji_events;
      iconColor = Colors.amber;
      label = "GOLD";
    } else {
      icon = Icons.workspace_premium;
      iconColor = Colors.white;
      label = "GRATUIT";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: label == "GRATUIT"
                    ? null
                    : () {
                        if (label == "GOLD") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SwipplyGoldDetailsPage()),
                          );
                        } else if (label == "PREMIUM") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const SwipplyPremiumDetailsPage()),
                          );
                        }
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    label == "GRATUIT" ? "Offre actuelle" : "Mettre à niveau",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...featureSections.entries.map((entry) {
            final sectionTitle = entry.key;
            final sectionIndexes = entry.value;
            return buildSection(sectionTitle, sectionIndexes, included);
          }),
        ],
      ),
    );
  }

  LinearGradient getButtonGradient(int index) {
    if (index == 0) {
      return const LinearGradient(colors: [blue_gray, black_gray]);
    } else if (index == 1) {
      return const LinearGradient(
          colors: [Color(0xFFFEEEC6), Color(0xFFFFD97D)]);
    } else {
      return const LinearGradient(
          colors: [Color(0xFFE6E6E6), Color(0xFFFFFFFF)]);
    }
  }

  void navigateToPlan() {
    if (_currentPage == 1) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SwipplyGoldDetailsPage()));
    } else if (_currentPage == 2) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SwipplyPremiumDetailsPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blue_gray,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 15,
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: white,
                    size: 30,
                  ),
                ),
                const Expanded(
                    child: SizedBox(
                  width: 1,
                )),
                const Padding(
                  padding: EdgeInsets.only(right: 45),
                  child: Text(
                    "Mes abonnements",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(
                    child: SizedBox(
                  width: 1,
                )),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: PageView.builder(
                controller: _topController,
                itemCount: 3,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final borderColor = index == 0
                      ? Colors.white
                      : index == 1
                          ? Colors.amber
                          : Colors.cyanAccent;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 2),
                      gradient: LinearGradient(
                        colors: [
                          index == 0
                              ? blue_gray
                              : index == 1
                                  ? const Color(0xFFFEEEC6)
                                  : const Color(0xFFE6E6E6),
                          index == 0
                              ? black_gray
                              : index == 1
                                  ? const Color(0xFFFFD97D)
                                  : const Color(0xFFFFFFFF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Swipply",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: index == 0 ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Transform(
                          transform: Matrix4.skewX(-0.3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: index == 0 ? Colors.white : Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ["GRATUIT", "GOLD", "PREMIUM"][index],
                              style: TextStyle(
                                color: index == 0 ? Colors.black : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentPage == index ? 10 : 8,
                  height: _currentPage == index ? 10 : 8,
                  decoration: BoxDecoration(
                    color:
                        _currentPage == index ? Colors.white : Colors.white30,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: buildPlanCard(
                  _currentPage == 0
                      ? "Swipply"
                      : _currentPage == 1
                          ? "Swipply Gold"
                          : "Swipply Premium",
                  _currentPage == 2,
                  _currentPage == 0
                      ? includedInFree
                      : _currentPage == 1
                          ? includedInGold
                          : includedInPlatinum,
                ),
              ),
            ),
            GestureDetector(
              onTap: _currentPage == 0 ? null : navigateToPlan,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: getButtonGradient(_currentPage),
                  borderRadius: BorderRadius.circular(14),
                  border: _currentPage == 0
                      ? Border.all(color: Colors.white, width: 1.6)
                      : null,
                ),
                child: Center(
                  child: Text(
                    _currentPage == 0
                        ? "Activé"
                        : _currentPage == 1
                            ? "Activer pour 4.99€ / month"
                            : "Activer pour 9.99€ / month",
                    style: TextStyle(
                      color: _currentPage == 0 ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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
}
