import 'package:flutter/material.dart';

class GoldSubscriptionCard extends StatelessWidget {
  final List<String> features;
  final List<bool> includedInFree;
  final List<bool> includedInGold;

  const GoldSubscriptionCard({
    super.key,
    required this.features,
    required this.includedInFree,
    required this.includedInGold,
    required List<bool> includedInPlan,
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 25),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFEEEC6), Color(0xFFFFD97D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33FFD97D),
            blurRadius: 12,
            offset: Offset(0, 6),
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
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Color.fromARGB(255, 241, 181, 0),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  const Text(
                    "Gold",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "Upgrade",
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

          Row(
            children: const [
              Expanded(
                flex: 6,
                child: Text(
                  "Ce qui est inclus",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Gratuit",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black),
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
                      color: Colors.black),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(thickness: 1.2, height: 22),

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
                          const TextStyle(fontSize: 13.5, color: Colors.black),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(child: _buildCheck(includedInFree[index])),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(child: _buildCheck(includedInGold[index])),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 18),

          const Center(
            child: Text(
              "Voir toutes les options",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB48A00),
              ),
            ),
          )
        ],
      ),
    );
  }
}
