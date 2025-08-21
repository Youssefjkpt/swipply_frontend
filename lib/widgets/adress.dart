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
  bool addressPicked = false;
  String? pickedAddress;

  String selectedCountryCode = '+33';
  String selectedCountryFlag = '🇫🇷';

  bool phoneValid = false;
  String? phoneError;
  String? phoneE164;

  @override
  void initState() {
    super.initState();
    initializePhoneAndAddress();
    loadCountryPreference();
  }

  String removeCountryCode(String phoneNumber) {
    String rawNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    String cc = selectedCountryCode.replaceAll('+', '');
    if (rawNumber.startsWith(cc)) rawNumber = rawNumber.substring(cc.length);
    return rawNumber;
  }

  void initializePhoneAndAddress() {
    String initialRawPhone = removeCountryCode(widget.initialPhone);
    phoneController = TextEditingController(text: initialRawPhone);
    addressController = TextEditingController(text: widget.initialAddress);
    phoneController.addListener(_enforceFrenchPhone);
    addressPicked = widget.initialAddress.trim().isNotEmpty;
    pickedAddress =
        widget.initialAddress.trim().isNotEmpty ? widget.initialAddress : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceFrenchPhone());
  }

  void _enforceFrenchPhone() {
    if (selectedCountryCode == '+33') {
      String digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('33')) digits = digits.substring(2);
      if (digits.startsWith('0')) digits = digits.substring(1);
      if (digits.length > 9) digits = digits.substring(0, 9);
      final valid = digits.length == 9 && !digits.startsWith('0');
      final buf = StringBuffer();
      for (int i = 0; i < digits.length; i++) {
        if (i > 0 && i % 2 == 0) buf.write(' ');
        buf.write(digits[i]);
      }
      final formatted = buf.toString();
      if (phoneController.text.replaceAll(' ', '') != digits) {
        phoneController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
      setState(() {
        phoneValid = valid;
        phoneError =
            valid ? null : 'Format FR: +33 et 9 chiffres (sans 0 initial).';
        phoneE164 = valid ? '+33$digits' : null;
      });
    } else {
      final raw = phoneController.text.trim();
      setState(() {
        phoneValid = raw.isNotEmpty;
        phoneError = raw.isNotEmpty ? null : 'Numéro requis';
        phoneE164 = null;
      });
    }
  }

  Future<void> fetchAddressSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        addressSuggestions = [];
        addressPicked = false;
        pickedAddress = null;
      });
      return;
    }
    setState(() {
      addressPicked = false;
      pickedAddress = null;
    });
    final response = await http.get(
      Uri.parse(
          'https://swipply-backend.onrender.com/api/address-autocomplete?query=$query'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        addressSuggestions = List<String>.from(data['addresses'] ?? []);
      });
    } else {
      setState(() {
        addressSuggestions = [];
      });
    }
  }

  void pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: blue_gray,
        textStyle: const TextStyle(color: white),
        inputDecoration: InputDecoration(
          hintText: 'Rechercher un pays',
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
        _enforceFrenchPhone();
        saveCountryPreference(selectedCountryCode, selectedCountryFlag);
      },
    );
  }

  Future<void> saveCountryPreference(String code, String flag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCountryCode', code);
    await prefs.setString('selectedCountryFlag', flag);
  }

  Future<void> loadCountryPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCountryCode = prefs.getString('selectedCountryCode') ?? '+33';
      selectedCountryFlag = prefs.getString('selectedCountryFlag') ?? '🇫🇷';
    });
    if (phoneController.text.isNotEmpty) {
      phoneController.text = removeCountryCode(phoneController.text);
      _enforceFrenchPhone();
    }
  }

  @override
  void dispose() {
    phoneController.removeListener(_enforceFrenchPhone);
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        addressPicked && (selectedCountryCode != '+33' || phoneValid);
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
                      borderRadius: BorderRadius.circular(100)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Modifier les info de contact',
                style: TextStyle(
                    color: white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Container(
                height: 78,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: black_gray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: phoneValid
                          ? Colors.green
                          : (phoneError != null
                              ? Colors.red
                              : Colors.transparent)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: pickCountry,
                      child: Container(
                        height: 60,
                        decoration: const BoxDecoration(
                            border: Border(right: BorderSide(color: white))),
                        child: Row(
                          children: [
                            Text('$selectedCountryFlag $selectedCountryCode',
                                style: const TextStyle(
                                    color: white, fontSize: 16)),
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
                          decoration: InputDecoration(
                            hintText: 'Entrer le numéro de téléphone',
                            hintStyle: const TextStyle(color: white_gray),
                            border: InputBorder.none,
                            errorText: phoneError,
                            suffixIcon: phoneValid
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
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
                decoration: InputDecoration(
                  labelText: 'Adresse',
                  labelStyle: const TextStyle(color: white_gray),
                  filled: true,
                  fillColor: black_gray,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: addressPicked
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
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
                      title: Text(addressSuggestions[index],
                          style: const TextStyle(color: white_gray)),
                      onTap: () {
                        setState(() {
                          pickedAddress = addressSuggestions[index];
                          addressController.text = pickedAddress!;
                          addressSuggestions.clear();
                          addressPicked = true;
                        });
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 25),
              GestureDetector(
                onTap: () {
                  if (!canSave) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Vérifie le numéro et sélectionne une adresse proposée')),
                    );
                    return;
                  }
                  final toSave = phoneE164 ??
                      '$selectedCountryCode ${phoneController.text.trim()}';
                  widget.onSave(toSave, addressController.text.trim());
                  Navigator.pop(context);
                },
                child: Opacity(
                  opacity: canSave ? 1.0 : 0.5,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                        color: blue, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: const Center(
                      child: Text('Enregistrer',
                          style: TextStyle(
                              color: white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
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
