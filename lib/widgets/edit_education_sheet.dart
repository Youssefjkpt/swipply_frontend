import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

import 'delete_icon.dart';

class EditEducationSheet extends StatefulWidget {
  final List<String> educations;
  final Function(List<String>) onSave;

  const EditEducationSheet({
    super.key,
    required this.educations,
    required this.onSave,
  });

  @override
  State<EditEducationSheet> createState() => _EditEducationSheetState();
}

class _EditEducationSheetState extends State<EditEducationSheet> {
  late List<TextEditingController> controllers;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controllers =
        widget.educations.map((e) => TextEditingController(text: e)).toList();
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addExperience() {
    setState(() {
      controllers.add(TextEditingController());
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeExperience(int index) {
    setState(() {
      controllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: _scrollController,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 5,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Edit Education',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // 🔁 Dynamic experience fields with delete icon
              ...List.generate(controllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controllers[index],
                          maxLines: null,
                          style: const TextStyle(color: white),
                          decoration: InputDecoration(
                            hintText: 'Education ${index + 1}',
                            hintStyle: const TextStyle(color: white_gray),
                            filled: true,
                            fillColor: black_gray,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) {
                            setState(() {}); // Refresh live preview
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      DeleteIconButton(
                        onPressed: () => _removeExperience(index),
                      ),
                    ],
                  ),
                );
              }),

              // ➕ Add new button
              TextButton.icon(
                onPressed: _addExperience,
                icon: const Icon(Icons.add, color: blue),
                label: const Text(
                  'Add Education',
                  style: TextStyle(color: blue),
                ),
              ),

              const SizedBox(height: 20),

              // 🔍 Live Preview (optional)
              if (controllers.any((c) => c.text.trim().isNotEmpty)) ...[
                const Text(
                  'Preview:',
                  style: TextStyle(
                      color: white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: controllers
                        .where((c) => c.text.trim().isNotEmpty)
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle,
                                      color: blue, size: 6),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.text.trim(),
                                      style: const TextStyle(
                                        color: white_gray,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // ✅ Save
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final updated = controllers
                      .map((c) => c.text.trim())
                      .where((text) => text.isNotEmpty)
                      .toList();
                  Navigator.pop(context, updated);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
