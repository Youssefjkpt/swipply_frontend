import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:http/http.dart' as http;

/// Warning card for email backup, matching dark theme with red accent.
class WarningEmailBackupCard extends StatelessWidget {
  final String warningLottieAsset;

  const WarningEmailBackupCard({
    Key? key,
    required this.warningLottieAsset,
  }) : super(key: key);

  Future<void> _saveBackupEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('second_email', email);

    final token = prefs.getString('token');
    final userId = prefs.getString('user_id');
    if (token == null || userId == null) return;

    final uri = Uri.parse('$BASE_URL_AUTH/api/users/$userId/second-email');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'second_email': email}),
    );

    if (response.statusCode != 200) {
      // handle error…
      print('❌ Failed to save second email: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBackupEmailDialog(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Lottie.asset(
              warningLottieAsset,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "E-mail de secours",
                    style: TextStyle(
                      color: white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "Pensez à ajouter une adresse e-mail de secours pour ne rien manquer de vos notifications.",
                    style: TextStyle(
                      color: white_gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupEmailDialog(BuildContext context) {
    final TextEditingController _emailController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color.fromARGB(255, 27, 27, 27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          constraints: const BoxConstraints(minHeight: 220),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.email_outlined,
                color: Color(0xFFFF4C4C),
                size: 40,
              ),
              const SizedBox(height: 20),
              Center(
                child: const Text(
                  "Adresse e-mail de secours",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Entrez votre e-mail de secours',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2B2B2B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C2C2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          await _saveBackupEmail(email);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Enregistrer",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF2B2B2B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Annuler",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
