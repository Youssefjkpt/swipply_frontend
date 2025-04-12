import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

class SubscriptionComparisonCard extends StatelessWidget {
  final String planName;
  final String badgeText;
  final Color gradientStart;
  final Color gradientEnd;
  final List<String> features;
  final List<bool> includedInFree;
  final List<bool> includedInPlan;

  const SubscriptionComparisonCard({
    super.key,
    required this.planName,
    required this.badgeText,
    required this.gradientStart,
    required this.gradientEnd,
    required this.features,
    required this.includedInFree,
    required this.includedInPlan,
  });

  Widget _buildCheck(bool value) {
    return Icon(
      value ? Icons.check : Icons.remove,
      color: value ? white : white_gray,
      size: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      width: width * 0.85,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientEnd.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Free',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: white_gray,
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Text(
                  "Current",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 20),

          // 🧩 Headers row with alignment
          const Row(
            children: [
              Expanded(
                flex: 6,
                child: Text(
                  "What's Included",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Free",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Gold",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(thickness: 1.2, height: 22),

          // 🔘 Feature rows
          ...List.generate(features.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Text(
                      features[index],
                      style:
                          const TextStyle(fontSize: 13.5, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(child: _buildCheck(includedInFree[index])),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(child: _buildCheck(includedInPlan[index])),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 18),

          const Center(
            child: Text(
              "See All Features",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: white_gray,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class PlatinumSubscriptionCard extends StatelessWidget {
  final List<String> features;
  final List<bool> includedInFree;
  final List<bool> includedInGold;
  final List<bool> includedInPlatinum;

  const PlatinumSubscriptionCard({
    super.key,
    required this.features,
    required this.includedInFree,
    required this.includedInGold,
    required this.includedInPlatinum,
  });

  Widget _buildCheck(bool value) {
    return Icon(
      value ? Icons.check : Icons.remove,
      color: value ? Colors.black : Colors.black.withOpacity(0.3),
      size: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      width: width * 0.85,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6E6E6), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.diamond, color: Colors.black87, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Platinum",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Text(
                  "Upgrade",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Header row
          const Row(
            children: [
              Expanded(
                flex: 6,
                child: Text(
                  "What's Included",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Gold",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "Platinum",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(thickness: 1.2, color: Colors.black12),

          // Feature rows
          ...List.generate(features.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Text(
                      features[index],
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(child: _buildCheck(includedInGold[index])),
                  ),
                  Expanded(
                    flex: 3,
                    child:
                        Center(child: _buildCheck(includedInPlatinum[index])),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          const Center(
            child: Text(
              "See All Features",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        ],
      ),
    );
  }
}
