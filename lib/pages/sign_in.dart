import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/gold_purchase_plan.dart';
import 'package:swipply/pages/main_layout.dart';
import 'package:swipply/pages/sign_up.dart';
import 'package:swipply/services/api_service.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _serverError;
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
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

  Future<void> saveUserSession(String userId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('token', token);
  }

  void _signIn() async {
    setState(() {
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
      _serverError = null;
    });

    if (_emailError == null && _passwordError == null) {
      showLoadingPopup(context);

      final result = await ApiService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      hideLoadingPopup(context);

      if (result is Map<String, dynamic> && result.containsKey("token")) {
        final userId = result['user']['user_id'].toString();
        final token = result['token'];

        await saveUserSession(userId, token);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Connexion réussie ✅"),
          backgroundColor: Colors.green,
        ));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else if (result is String) {
        setState(() => _serverError = result);
      } else {
        setState(() => _serverError = "Erreur inattendue. Veuillez réessayer.");
      }
    }
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return "Please enter your email";
    final emailRegex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(email)) return "Enter a valid email";
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return "Please enter your password";
    if (password.length < 6) return "Password must be at least 6 characters";
    return null;
  }

  Future<void> _signInWithGoogle() async {
    try {
      showLoadingPopup(context);

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        hideLoadingPopup(context);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final response = await http.post(
        Uri.parse('$BASE_URL_JOBS/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': googleAuth.idToken}),
      );

      hideLoadingPopup(context);

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveUserSession(
          jsonResponse['user']['user_id'].toString(),
          jsonResponse['token'],
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Google Sign-In Successful"),
          backgroundColor: Colors.green,
        ));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else {
        setState(() {});
      }
    } catch (e, stack) {
      hideLoadingPopup(context);
      print("🔥 Error in Google Sign-In: $e");
      print("📌 StackTrace: $stack");
      setState(() {});
    }
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

                // Welcome Text
                const Text(
                  'Welcome Back 👋',
                  style: TextStyle(
                      fontSize: 28, color: white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Let's log in. Apply to jobs!",
                  style: TextStyle(
                      fontSize: 18, color: gray, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),

                // Email Input
                const Text(
                  'Email Address',
                  style: TextStyle(
                      fontSize: 17, color: white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildInputField("E-mail", _emailController, _emailError),
                const SizedBox(height: 20),

                // Password Input
                const Text(
                  'Password',
                  style: TextStyle(
                      fontSize: 17, color: white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildPasswordField(),

                const SizedBox(height: 15),

                // Forgot Password
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                        color: blue, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 30),

                // Server Error Message
                if (_serverError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _serverError!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),

                // Sign In Button
                GestureDetector(
                  onTap: _isLoading ? null : _signIn,
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _isLoading ? gray : blue,
                    ),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: white)
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                  color: white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: white, fontSize: 16)),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SignUp())),
                      child: const Text(
                        "Register",
                        style: TextStyle(
                            color: blue,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                GestureDetector(
                    onTap: _signInWithGoogle,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.075,
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
      String hint, TextEditingController controller, String? error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border:
                Border.all(color: error == null ? gray : Colors.red, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
            child: TextFormField(
              controller: controller,
              style: const TextStyle(color: white, fontSize: 16),
              cursorColor: blue,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: gray, fontSize: 16),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error,
                style: const TextStyle(color: Colors.red, fontSize: 14)),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return _buildInputField(
        "Enter your password", _passwordController, _passwordError);
  }
}
