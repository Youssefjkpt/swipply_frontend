import 'dart:math';

import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/widgets/edit_education_sheet.dart';

class EducationSection extends StatelessWidget {
  final List<String> educations;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final VoidCallback onEdit;

  const EducationSection({
    Key? key,
    required this.educations,
    required this.showAll,
    required this.onToggleShowAll,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: GestureDetector(
          onTap: onEdit,
          child: Container(
            decoration: BoxDecoration(
                color: blue_gray, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Formation',
                    style: TextStyle(
                        color: white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.edit, color: white_gray, size: 20),
              ]),
              const SizedBox(height: 15),
              ...List.generate(
                showAll ? educations.length : min(3, educations.length),
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.school, color: blue, size: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(educations[i],
                                style: const TextStyle(
                                    color: white_gray, fontSize: 15))),
                      ]),
                ),
              ),
              if (educations.length > 3)
                GestureDetector(
                  onTap: onToggleShowAll,
                  child: Text(showAll ? 'Voir moins' : 'Voir plus',
                      style: const TextStyle(
                          color: blue,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ),
            ]),
          ),
        ),
      );
}
