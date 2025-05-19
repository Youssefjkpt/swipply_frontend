import 'dart:convert';
import 'package:country_picker/country_picker.dart';
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
  String selectedCountryCode = '+33'; // Default to France
  String selectedCountryFlag = '🇫🇷'; // Default to France flag

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController(text: widget.initialPhone);
    addressController = TextEditingController(text: widget.initialAddress);
    phoneController.addListener(formatPhoneNumber);
  }

  // Automatic French Phone Number Formatting
  void formatPhoneNumber() {
    if (selectedCountryCode == '+33') {
      String rawNumber = phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (rawNumber.length > 10) rawNumber = rawNumber.substring(0, 10);

      String formattedNumber = '';
      for (int i = 0; i < rawNumber.length; i++) {
        if (i > 0 && i % 2 == 0) formattedNumber += ' ';
        formattedNumber += rawNumber[i];
      }
      phoneController.value = TextEditingValue(
        text: formattedNumber.trim(),
        selection: TextSelection.collapsed(offset: formattedNumber.length),
      );
    }
  }

  Future<void> fetchAddressSuggestions(String query) async {
    if (query.isEmpty) return;
    final response = await http.get(
      Uri.parse(
          'https://swipply-backend.onrender.com/api/address-autocomplete?query=$query'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        addressSuggestions = List<String>.from(data['addresses']);
      });
    }
  }

  // Open Country Picker with All Countries
  void pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: blue_gray,
        textStyle: const TextStyle(color: white),
        inputDecoration: InputDecoration(
          hintText: 'Search Country',
          hintStyle: const TextStyle(color: white_gray),
          filled: true,
          fillColor: black_gray,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          selectedCountryCode = '+${country.phoneCode}';
          selectedCountryFlag = country.flagEmoji;
          phoneController.clear(); // Clear phone number when country changes
        });
      },
    );
  }

  @override
  void dispose() {
    phoneController.removeListener(formatPhoneNumber);
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

              // Phone Number Field with Country Picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: black_gray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: pickCountry,
                      child: Row(
                        children: [
                          Text(
                            '$selectedCountryFlag $selectedCountryCode',
                            style: const TextStyle(color: white, fontSize: 16),
                          ),
                          const Icon(Icons.arrow_drop_down, color: white),
                        ],
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: white_gray,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: phoneController,
                        style: const TextStyle(color: white),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Enter phone number',
                          hintStyle: TextStyle(color: white_gray),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Address',
                style: TextStyle(color: white, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: addressController,
                style: const TextStyle(color: white),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: black_gray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 25),
              // Save Button
              GestureDetector(
                onTap: () {
                  widget.onSave(
                    '$selectedCountryCode ${phoneController.text.trim()}',
                    addressController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Save',
                        style: TextStyle(
                            color: white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                    ),
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
