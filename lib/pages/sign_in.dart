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

  Future<void> ensureIdentityPrefs({
    required String userId,
    required String token,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1) always refresh session id & token
    await prefs.setString('user_id', userId);
    await prefs.setString('token', token);

    // 2) if the phone has never stored an email / plan, seed them
    if ((prefs.getString('user_email') ?? '').isEmpty) {
      await prefs.setString('user_email', email);
    }
    if (!prefs.containsKey('plan_name')) {
      await prefs.setString('plan_name', 'Free'); // first login ⇒ Free
    }
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
        final email = result['user']['email'] ?? '';
        await ensureIdentityPrefs(
          userId: userId,
          token: token,
          email: email,
        );
        await _setCvCompleteFlag(userId);
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
    if (email.isEmpty) return "Veuillez saisir votre e-mail";
    final emailRegex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(email)) return "Entrez un e-mail valide";
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return "Veuillez saisir votre mot de passe";
    if (password.length < 6)
      return "Le mot de passe doit comporter au moins 6 caractères";
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
        final userId = jsonResponse['user']['user_id'].toString();
        final token = jsonResponse['token'];
        final email = jsonResponse['user']['email'] ?? '';
        await ensureIdentityPrefs(
          userId: userId,
          token: token,
          email: email,
        );
        await ensurePlanLocal('Free');
        await _setCvCompleteFlag(userId);
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

  Future<void> ensurePlanLocal([String defaultPlan = 'Free']) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('plan_name');
    if (current == null || current.isEmpty) {
      await prefs.setString('plan_name', defaultPlan);
    }
  }

  Future<void> _setCvCompleteFlag(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    // 1️⃣ Fetch user basic info
    final userRes = await http.get(
      Uri.parse('$BASE_URL_AUTH/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('🛰️ userRes.statusCode: ${userRes.statusCode}');
    print('🛰️ userRes.body: ${userRes.body}');

    // 2️⃣ Fetch employee record
    final empRes = await http.get(
      Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('🛰️ empRes.statusCode: ${empRes.statusCode}');
    print('🛰️ empRes.body: ${empRes.body}');

    if (userRes.statusCode == 200 && empRes.statusCode == 200) {
      final userData = json.decode(userRes.body);
      final empData = json.decode(empRes.body);

      final fullName = userData['full_name']?.toString().trim();
      final address = userData['address']?.toString().trim();
      final email = userData['email']?.toString().trim();
      final phone = userData['phone_number']?.toString().trim();

      final resume = empData['resume']?.toString().trim();
      final education = empData['education']?.toString().trim();
      final experience = empData['experience']?.toString().trim();

      final languages = empData['languages'] ?? [];
      final interests = empData['interests'] ?? [];
      final softSkills = empData['soft_skills'] ?? [];

      print('🔍 fullName       = $fullName');
      print('🔍 address        = $address');
      print('🔍 email          = $email');
      print('🔍 phone          = $phone');
      print('🔍 resume         = $resume');
      print('🔍 education      = $education');
      print('🔍 experience     = $experience');
      print('🔍 languages      = $languages');
      print('🔍 interests      = $interests');
      print('🔍 softSkills     = $softSkills');

      final bool complete = fullName != null &&
          fullName.isNotEmpty &&
          address != null &&
          address.isNotEmpty &&
          email != null &&
          email.isNotEmpty &&
          phone != null &&
          phone.isNotEmpty &&
          resume != null &&
          resume.isNotEmpty &&
          education != null &&
          education.isNotEmpty &&
          experience != null &&
          experience.isNotEmpty &&
          (languages is List && languages.isNotEmpty) &&
          (interests is List && interests.isNotEmpty) &&
          (softSkills is List && softSkills.isNotEmpty);

      print('✅ Computed cv_complete = $complete');
      await prefs.setBool('cv_complete', complete);
    } else {
      print('❌ Failed to fetch user/employee, clearing cv_complete flag');
      await prefs.remove('cv_complete');
    }
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
                  'Bon retour 👋',
                  style: TextStyle(
                      fontSize: 28, color: white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Connectez-vous et postulez à des offres !",
                  style: TextStyle(
                      fontSize: 18, color: gray, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),

                // Email Input
                const Text(
                  'Adresse e-mail',
                  style: TextStyle(
                      fontSize: 17, color: white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildInputField("E-mail", _emailController, _emailError),
                const SizedBox(height: 20),

                // Password Input
                const Text(
                  'Mot de passe',
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
                    'Mot de passe oublié ?',
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
                              'Se connecter',
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
                    const Text("Vous n'avez pas de compte? ",
                        style: TextStyle(color: white, fontSize: 16)),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SignUp())),
                      child: const Text(
                        "S'inscrire",
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
                      hintText: "Entrez votre mot de passe",
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
