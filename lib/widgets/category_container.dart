import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

class CategoryChip extends StatelessWidget {
  final String label;

  const CategoryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(92, 255, 255, 255),
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: white,
          fontSize: 15,
        ),
      ),
    );
  }
}
