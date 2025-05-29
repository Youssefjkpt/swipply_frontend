import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/main_layout.dart';
import 'package:swipply/pages/sign_up.dart';
import 'package:swipply/services/api_service.dart';
import 'package:swipply/widgets/check_mark_green_design.dart';
import 'package:swipply/widgets/loading.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> with TickerProviderStateMixin {
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
      _isLoading = true;
    });

    if (_emailError != null || _passwordError != null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
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

        showSuccessCheckPopup();
        await Future.delayed(const Duration(seconds: 2));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else {
        final errorMessage = result is String
            ? result
            : "Une erreur est survenue. Veuillez réessayer.";
        showErrorDialog(context, errorMessage);
      }
    } catch (e) {
      hideLoadingPopup(context);
      showErrorDialog(
          context, "Erreur réseau. Vérifiez votre connexion et réessayez.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void showErrorDialog(BuildContext context, String title, [String? message]) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: blue_gray,
        title: Row(
          children: [
            Transform.scale(
              scale: 1.5, // Increase the scale factor as needed
              child: Lottie.asset(
                warningicon,
              ),
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: white),
              ),
            ),
          ],
        ),
        content: Text(
          message ?? 'Une erreur est survenue. Veuillez réessayer.',
          style: const TextStyle(fontSize: 16, color: white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Fermer", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
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

        showSuccessCheckPopup();
        await Future.delayed(const Duration(seconds: 2));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else {
        showErrorDialog(
            context, "Échec de l’authentification Google. Veuillez réessayer.");
      }
    } catch (e) {
      hideLoadingPopup(context);
      showErrorDialog(context,
          "Erreur réseau lors de la connexion Google. Vérifiez votre connexion et réessayez.");
    }
  }

  void showSuccessCheckPopup() {
    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Center(
          child: Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _checkmarkController,
              builder: (_, __) => CustomPaint(
                painter: CheckMarkPainter(_checkmarkController),
              ),
            ),
          ),
        );
      },
    );

    // Start the animation after dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkmarkController.forward(from: 0);
    });

    // Close the dialog after 3 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  late AnimationController _checkmarkController;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: _passwordError == null ? gray : Colors.red, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: white, fontSize: 16),
                    cursorColor: blue,
                    obscureText: !_isPasswordVisible,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: "Enter your password",
                      hintStyle: TextStyle(color: gray, fontSize: 16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _togglePasswordVisibility,
                  child: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: gray,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_passwordError != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              _passwordError!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
      ],
    );
  }
}
