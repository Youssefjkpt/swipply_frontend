import 'dart:convert';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swipply/constants/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    loadCountryPreference();
    initializePhoneAndAddress();
  }

// This method ensures the country code is completely removed from the input field
  String removeCountryCode(String phoneNumber) {
    String rawNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Check if the phone number starts with the current country code (without "+")
    String countryCodeWithoutPlus = selectedCountryCode.replaceAll('+', '');
    if (rawNumber.startsWith(countryCodeWithoutPlus)) {
      rawNumber = rawNumber.substring(countryCodeWithoutPlus.length);
    }

    return rawNumber;
  }

// Initialize the phone number without the country code
  void initializePhoneAndAddress() {
    String initialRawPhone = removeCountryCode(widget.initialPhone);
    phoneController = TextEditingController(text: initialRawPhone);
    addressController = TextEditingController(text: widget.initialAddress);
    phoneController.addListener(formatPhoneNumber);
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

// Automatically format the phone number without the country code in input
  void formatPhoneNumber() {
    String rawNumber = removeCountryCode(phoneController.text);

    if (selectedCountryCode == '+33' && rawNumber.length > 10) {
      rawNumber = rawNumber.substring(0, 10);
    }

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

// Update the phone number without country code when switching countries
  void pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: blue_gray,
        textStyle: const TextStyle(color: white),
        inputDecoration: InputDecoration(
          hintText: '	Rechercher un pays',
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
          phoneController.text = removeCountryCode(phoneController.text);
        });
        saveCountryPreference(selectedCountryCode, selectedCountryFlag);
      },
    );
  }

// Save the selected country persistently
  Future<void> saveCountryPreference(String code, String flag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCountryCode', code);
    await prefs.setString('selectedCountryFlag', flag);
  }

// Load the saved country preference (without affecting the phone number)
  Future<void> loadCountryPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCountryCode = prefs.getString('selectedCountryCode') ?? '+33';
      selectedCountryFlag = prefs.getString('selectedCountryFlag') ?? '🇫🇷';
    });
    // Re-initialize the phone number without country code
    phoneController.text = removeCountryCode(phoneController.text);
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
                'Modifier les info de contact',
                style: TextStyle(
                  color: white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Phone Number Field with Country Picker
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: black_gray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: pickCountry,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: white))),
                        child: Row(
                          children: [
                            Text(
                              '$selectedCountryFlag $selectedCountryCode',
                              style:
                                  const TextStyle(color: white, fontSize: 16),
                            ),
                            const Icon(Icons.arrow_drop_down, color: white),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: TextFormField(
                          controller: phoneController,
                          style: const TextStyle(color: white),
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Entrer le numéro de téléphone',
                            hintStyle: TextStyle(color: white_gray),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: addressController,
                onChanged: fetchAddressSuggestions,
                style: const TextStyle(color: white),
                decoration: const InputDecoration(
                  labelText: 'Adresse',
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
                SizedBox(
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
                        'Enregistrer',
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
