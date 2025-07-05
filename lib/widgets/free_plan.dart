import 'package:flutter/material.dart';

class FreeSubscriptionCard extends StatelessWidget {
  final List<String> features;
  final List<bool> includedInFree;

  const FreeSubscriptionCard({
    super.key,
    required this.features,
    required this.includedInFree,
  });

  Widget _buildCheck(bool value) {
    return Icon(
      value ? Icons.check : Icons.lock,
      color: value ? Colors.green : Colors.grey.shade400,
      size: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      width: width * 0.85,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDEDED), Color(0xFFF9F9F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.25),
            blurRadius: 12,
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
              Row(
                children: [
                  const Text(
                    "Swipply",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "GRATUIT",
                      style: TextStyle(color: Colors.black87, fontSize: 10),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Text(
                  "Inclus",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Row(
            children: [
              Expanded(
                child: Text(
                  "Vos avantages",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Colors.black87,
                  ),
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
                      style: const TextStyle(
                          fontSize: 13.5, color: Colors.black87),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(child: _buildCheck(includedInFree[index])),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 18),

          const Center(
            child: Text(
              "Passez au plan supérieur",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          )
        ],
      ),
    );
  }
}
