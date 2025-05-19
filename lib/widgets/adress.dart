import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swipply/constants/themes.dart';

class EditContactInfoSheet extends StatefulWidget {
  final String initialPhone;
  final String initialAddress;
  final void Function(String phone, String address) onSave;

  const EditContactInfoSheet({
    super.key,
    required this.initialPhone,
    required this.initialAddress,
    required this.onSave,
  });

  @override
  State<EditContactInfoSheet> createState() => _EditContactInfoSheetState();
}

class _EditContactInfoSheetState extends State<EditContactInfoSheet> {
  late TextEditingController phoneController;
  late TextEditingController addressController;
  List<String> addressSuggestions = [];

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController(text: widget.initialPhone);
    addressController = TextEditingController(text: widget.initialAddress);
  }

  Future<void> fetchAddressSuggestions(String query) async {
    if (query.isEmpty) return;
    print("Fetching suggestions for: $query");

    final response = await http.get(
      Uri.parse(
          'https://swipply-backend.onrender.com/api/address-autocomplete?query=$query'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        addressSuggestions = List<String>.from(data['addresses']);
      });
      print("API Response: ${response.body}");
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.6,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 6,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Contact Info',
                style: TextStyle(
                  color: white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: phoneController,
                style: const TextStyle(color: white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: white_gray),
                  filled: true,
                  fillColor: black_gray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: addressController,
                onChanged: fetchAddressSuggestions,
                style: const TextStyle(color: white),
                decoration: const InputDecoration(
                  labelText: 'Address',
                  labelStyle: TextStyle(color: white_gray),
                  filled: true,
                  fillColor: black_gray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (addressSuggestions.isNotEmpty)
                Container(
                  height: 180,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: addressSuggestions.length,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(
                        addressSuggestions[index],
                        style: const TextStyle(color: white_gray),
                      ),
                      onTap: () {
                        setState(() {
                          addressController.text = addressSuggestions[index];
                          addressSuggestions.clear();
                        });
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 25),
              GestureDetector(
                  onTap: () {
                    widget.onSave(
                      phoneController.text.trim(),
                      addressController.text.trim(),
                    );
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                        color: blue, borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ))
            ],
          ),
        );
      },
    );
  }
}
