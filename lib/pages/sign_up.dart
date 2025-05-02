// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'dart:convert';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/cv.dart';
import 'package:swipply/pages/main_layout.dart';
import 'package:swipply/pages/sign_in.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _passwordStrength = "";

  Future<void> saveUserSession(String userId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('token', token);
  }

  @override
  void initState() {
    super.initState();
  }

  void checkUsers() async {
    final response = await http.get(Uri.parse("$BASE_URL_AUTH/users/check"));
    print("Users in Database: ${response.body}");
  }

  Future<void> _signUpWithGoogle() async {
    try {
      showLoadingPopup(context);

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            '463526138738-v3ejoh5jdfd4pr1e90s58mksbak9cbdf.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        hideLoadingPopup(context);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final response = await http.post(
        Uri.parse('$BASE_URL_JOBS/auth/google'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": googleAuth.idToken}),
      );

      final jsonResponse = jsonDecode(response.body);

      hideLoadingPopup(context);

      if (response.statusCode == 200) {
        await saveUserSession(
          jsonResponse['user']['user_id'].toString(),
          jsonResponse['token'],
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else {
        setState(() {
          _errorMessage = jsonResponse["error"] ?? "Google Sign-In Failed";
        });
      }
    } catch (e) {
      hideLoadingPopup(context);
      setState(() {
        _errorMessage = "Error during Google Sign-In";
      });
    }
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text.trim() !=
          _confirmPasswordController.text.trim()) {
        setState(() {
          _errorMessage = "Les mots de passe ne correspondent pas.";
        });
        return;
      }
      showLoadingPopup(context);
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final requestBody = jsonEncode({
        "full_name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "phone_number": "0000000000",
        "password": _passwordController.text.trim(),
      });

      try {
        var response = await http.post(
          Uri.parse('$BASE_URL_AUTH/api/signup'),
          headers: {"Content-Type": "application/json"},
          body: requestBody,
        );

        print("📦 Signup response status: ${response.statusCode}");
        print("📦 Signup response body: ${response.body}");

        final jsonResponse = jsonDecode(response.body);
        print("🧠 JSON: $jsonResponse");

        if (response.statusCode == 201) {
          await saveUserSession(
              jsonResponse['user_id'].toString(), jsonResponse['token'] ?? '');

          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => MainLayout()));
        } else {
          setState(() {
            _errorMessage = jsonResponse["error"] ?? "Erreur inconnue.";
          });
        }
      } catch (e) {
        print("❌ Signup error (exception): $e");
        setState(() {
          _errorMessage = "Erreur de connexion au serveur.";
        });
      }

      setState(() => _isLoading = false);
    }
  }

  void showLoadingPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: blue_gray,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: const LoadingBars(),
            ),
          ),
        ),
      ),
    );
  }

  void hideLoadingPopup(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      if (password.length < 6) {
        _passwordStrength = "Faible";
      } else if (password.length < 10) {
        _passwordStrength = "Moyen";
      } else {
        _passwordStrength = "Fort";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                const Text(
                  'Créez votre compte 👋',
                  style: TextStyle(
                      fontSize: 28, color: white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Inscrivez-vous et commencez à postuler aux offres d\'emploi !',
                  style: TextStyle(
                      fontSize: 18, color: gray, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInputField(
                          "Nom complet", "Entrez votre nom", _nameController),
                      const SizedBox(height: 15),
                      _buildInputField("Adresse e-mail", "Entrez votre e-mail",
                          _emailController),
                      const SizedBox(height: 15),
                      _buildPasswordField(
                        "Mot de passe",
                        "Entrez votre mot de passe",
                        _passwordController,
                        _isPasswordVisible,
                        () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        _checkPasswordStrength,
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.only(top: 5),
                      //   child: Text(
                      //     _passwordStrength,
                      //     style: TextStyle(
                      //       color: _passwordStrength == "Faible"
                      //           ? Colors.red
                      //           : _passwordStrength == "Moyen"
                      //               ? Colors.orange
                      //               : Colors.green,
                      //       fontSize: 14,
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(height: 15),
                      _buildPasswordField(
                        "Confirmer le mot de passe",
                        "Ré-entrez votre mot de passe",
                        _confirmPasswordController,
                        _isConfirmPasswordVisible,
                        () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                        null,
                      ),

                      // Row(
                      //   children: [
                      //     Checkbox(
                      //       value: _isTermsAccepted,
                      //       onChanged: (value) {
                      //         setState(() {
                      //           _isTermsAccepted = value!;
                      //         });
                      //       },
                      //       activeColor: blue,
                      //     ),
                      //     const Expanded(
                      //       child: Text(
                      //         "En cochant cette case, vous acceptez nos termes et conditions.",
                      //         style: TextStyle(color: white, fontSize: 14),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 14)),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildButton("Ignorer", gray, () {})),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildButton(
                              _isLoading ? "Inscription..." : "S'inscrire",
                              blue,
                              _isLoading ? () {} : _signUp,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _signUpWithGoogle,
                            child: Container(
                              height:
                                  MediaQuery.of(context).size.height * 0.075,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: white,
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Image.asset(
                                          google,
                                          height: 35,
                                          width: 35,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Continuer avec Google',
                                          style: TextStyle(
                                            color: black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: black,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Vous avez déjà",
                                  style: TextStyle(color: white, fontSize: 16)),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const SignIn()));
                                },
                                child: const Text(
                                  " Se connecter",
                                  style: TextStyle(
                                    color: blue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildPasswordField(
  String label,
  String hintText,
  TextEditingController controller,
  bool isVisible,
  VoidCallback toggleVisibility,
  Function(String)? onChanged, // ✅ Ensure this argument exists
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 17, color: white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: gray, width: 2)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
          child: TextFormField(
            controller: controller,
            obscureText: !isVisible,
            style: const TextStyle(color: white, fontSize: 16),
            cursorColor: blue,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(color: gray, fontSize: 16)),
            onChanged: onChanged, // ✅ Ensure this is used
          ),
        ),
      ),
    ],
  );
}

Widget _buildInputField(
    String label, String hintText, TextEditingController controller) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 17, color: white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: gray, width: 2)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: white, fontSize: 16),
            cursorColor: blue,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(color: gray, fontSize: 16)),
            validator: (value) =>
                value == null || value.isEmpty ? "Ce champ est requis" : null,
          ),
        ),
      ),
    ],
  );
}

Widget _buildButton(String text, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 60,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(12), color: color),
      child: Center(
          child: Text(text,
              style: TextStyle(
                  color: white, fontSize: 20, fontWeight: FontWeight.w600))),
    ),
  );
}

Widget socialButton(String image) {
  return Container(
    height: 50,
    width: 50,
    decoration:
        BoxDecoration(color: white, borderRadius: BorderRadius.circular(100)),
    child: Padding(
        padding: const EdgeInsets.all(12),
        child: Image.asset(image, fit: BoxFit.contain)),
  );
}
