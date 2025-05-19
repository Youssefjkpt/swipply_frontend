import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/widgets/edit_education_sheet.dart';

class EducationSection extends StatefulWidget {
  final List<String> educations;

  const EducationSection({super.key, required this.educations});

  @override
  State<EducationSection> createState() => _EducationSectionState();
}

class _EducationSectionState extends State<EducationSection> {
  bool showAll = false;

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditEducationSheet(
        educations: widget.educations, // ✅ correct usage

        onSave: (updated) {
          setState(() {
            widget.educations.clear();
            widget.educations.addAll(updated);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎓 Title row
            Row(
              children: [
                const Text(
                  'Education',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openEditSheet,
                  child: const Icon(Icons.edit, color: white_gray, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 📋 Education items
            ...List.generate(
              showAll
                  ? widget.educations.length
                  : (widget.educations.length > 3
                      ? 3
                      : widget.educations.length),
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.school, color: blue, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.educations[index],
                        style: const TextStyle(
                          color: white_gray,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🔁 Read more / less
            if (widget.educations.length > 3)
              GestureDetector(
                onTap: () => setState(() => showAll = !showAll),
                child: Text(
                  showAll ? 'Read less' : 'Read more',
                  style: const TextStyle(
                    color: blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
