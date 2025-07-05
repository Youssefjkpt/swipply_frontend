// ignore_for_file: unused_field

import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as siwa;
import 'package:swipply/constants/images.dart';
import 'dart:convert';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/main_layout.dart';
import 'package:swipply/pages/sign_in.dart';
import 'package:swipply/widgets/check_mark_green_design.dart';
import 'package:swipply/widgets/loading.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show
        SignInWithApple,
        AuthorizationCredentialAppleID,
        SignInWithAppleAuthorizationException,
        AuthorizationErrorCode,
        AppleIDAuthorizationScopes;

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> with TickerProviderStateMixin {
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
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _serverError;
  void _toggleConfirmPasswordVisibility() {
    setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
  }
// Above your other methods:

  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
  }

  Future<void> saveUserSession(
      {required String userId,
      required String token,
      required String email, // new
      required String planName // new
      }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('token', token);
    await prefs.setString('user_email', email);
    await prefs.setString(
        'plan_name', planName); // 'Free' | 'Gold' | 'Platinum'
  }

  Future<void> markCvIncomplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cv_complete', false);
  }

  @override
  void initState() {
    super.initState();
  }

  void checkUsers() async {
    final response = await http.get(Uri.parse("$BASE_URL_AUTH/users/check"));
    print("Users in Database: ${response.body}");
  }

  String? _validateEmail(String value) {
    final emailRx = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (value.trim().isEmpty) return 'Email requis';
    if (!emailRx.hasMatch(value)) return 'Email invalide';
    return null;
  }

  String? _validatePassword(String value) {
    if (value.trim().isEmpty) return 'Mot de passe requis';
    if (value.length < 6) return 'Minimum 6 caractères';
    return null;
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

  Future<void> _syncCvStatus(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final res = await http.get(
      Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      // if resume exists and non-empty, mark complete, else incomplete
      final hasResume = (data['resume'] as String?)?.isNotEmpty == true;
      await prefs.setBool('cv_complete', hasResume);
    } else {
      // no record → brand-new user
      await prefs.setBool('cv_complete', false);
    }
  }

  String plan = 'Free';
  /* --------------------------------------------------------------------------
 * 1.  SIGN-UP  (email / password)
 * --------------------------------------------------------------------------*/
  Future<void> _signUp() async {
    //-- local validation ------------------------------------------------------
    setState(() {
      _errorMessage = null;
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
      _confirmPasswordError =
          (_passwordController.text != _confirmPasswordController.text)
              ? 'Les mots de passe ne correspondent pas'
              : null;
      _isLoading = true;
    });

    if (_emailError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      setState(() => _isLoading = false);
      return;
    }

    /* ---- server request --------------------------------------------------- */
    showLoadingPopup(context);

    final body = jsonEncode({
      'full_name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone_number': '0000000000',
      'password': _passwordController.text.trim(),
    });

    try {
      final res = await http.post(
        Uri.parse('$BASE_URL_AUTH/api/signup'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      hideLoadingPopup(context);

      final data = jsonDecode(res.body);

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final uid = data['user']['user_id'].toString();
        final token = data['token'] as String;
        final email = data['user']['email'] as String? ?? '';

        saveUserSession(
            userId: uid, token: token, email: email, planName: 'Free');
        await _setCvCompleteFlag(uid);
        await markCvIncomplete();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'plan_name', plan); // 'Gold' | 'Platinum' | 'Free'

        // <-- new: mark CV as incomplete
        showSuccessCheckPopup();
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else {
        showErrorDialog(
          context,
          'Erreur',
          data?['error'] ?? 'Une erreur est survenue. Veuillez réessayer.',
        );
      }
    } catch (e) {
      hideLoadingPopup(context);
      showErrorDialog(
        context,
        'Erreur réseau',
        'Veuillez vérifier votre connexion internet et réessayer.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

/* --------------------------------------------------------------------------
 * 2.  SIGN-UP  WITH  GOOGLE
 * --------------------------------------------------------------------------*/
  /*  SIGN-UP WITH GOOGLE  */
  // ===== Google / Firebase =====
  static const _kWebClientId =
      '463526138738-v3ejoh5jdfd4pr1e90s58mksbak9cbdf.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignUp = GoogleSignIn(
    serverClientId: _kWebClientId, // <— makes idToken non-null on iOS
    scopes: ['email', 'profile'],
  );

  Future<void> _signUpWithGoogle() async {
    try {
      showLoadingPopup(context);

      final googleUser = await _googleSignUp.signIn();
      if (googleUser == null) {
        hideLoadingPopup(context); // user cancelled
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        hideLoadingPopup(context);
        showErrorDialog(context, 'Token Google manquant. Réessayez plus tard.');
        return;
      }

      final res = await http.post(
        Uri.parse('$BASE_URL_JOBS/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': idToken}),
      );

      hideLoadingPopup(context);
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data?['token'] != null) {
        final uid = data['user']['user_id'].toString();

        await saveUserSession(
          userId: uid,
          token: data['token'],
          email: data['user']['email'] ?? '',
          planName: 'Free',
        );

        await _setCvCompleteFlag(uid);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('plan_name', plan);

        showSuccessCheckPopup();
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout()),
        );
      } else {
        showErrorDialog(
            context,
            'Erreur',
            data?['error'] ??
                "Échec de l'inscription avec Google. Veuillez réessayer.");
      }
    } catch (e) {
      hideLoadingPopup(context);
      final isNetwork = e.toString().contains('SocketException');
      showErrorDialog(
        context,
        'Erreur réseau',
        isNetwork
            ? "Veuillez vérifier votre connexion internet et réessayer."
            : "Échec de l'inscription avec Google. Veuillez réessayer.",
      );
    }
  }

  Future<void> showErrorDialog(
    BuildContext context,
    String title, [
    String? message,
  ]) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: blue_gray,
        title: Row(
          children: [
            Transform.scale(
              scale: 1.5,
              child: Lottie.asset(warningicon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: white,
                ),
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
            // IMPORTANT: pop the *dialog* route, not the page route
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('Fermer', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
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

  /* ──────────────────────────────────────────────────────────
   DROP THIS EXACT FUNCTION IN PLACE OF YOUR CURRENT VERSION
   (no hideLoadingPopup inside onError ⇒ no double-pop bug)
   ────────────────────────────────────────────────────────── */
  /* ─── replace your _signInWithApple() with this ────────────────────────── */
  Future<void> _signInWithApple() async {
    if (!await SignInWithApple.isAvailable()) {
      _showError('Sign in with Apple n’est pas disponible sur cet appareil.');
      return;
    }

    showLoadingPopup(context); // loader ON

    String _rnd([int l = 32]) =>
        List<int>.generate(l, (_) => Random.secure().nextInt(256))
            .map((i) => i.toRadixString(16).padLeft(2, '0'))
            .join();
    final rawNonce = _rnd();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    AuthorizationCredentialAppleID? cred;
    SignInWithAppleAuthorizationException? err;

    try {
      cred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      err = e; // hold until loader off
    }

    if (mounted) hideLoadingPopup(context); // loader OFF (once)

    if (err != null) {
      if (err.code == AuthorizationErrorCode.canceled) return; // user cancelled
      _showError('Impossible de se connecter avec Apple. Réessayez plus tard.');
      return;
    }

    if (cred == null || cred.identityToken == null) {
      _showError('Erreur Apple (AUTH-06). Veuillez réessayer.');
      return;
    }

    final resp = await http.post(
      Uri.parse('$BASE_URL_JOBS/auth/apple'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': cred.identityToken,
        'nonce': rawNonce,
      }),
    );

    if (resp.statusCode != 200) {
      _showError('Connexion Apple échouée (${resp.statusCode}).');
      return;
    }

    final data = jsonDecode(resp.body);
    final userId = data['user']['user_id'].toString();
    final token = data['token'];
    final email = data['user']['email'] ?? '';

    await ensureIdentityPrefs(userId: userId, token: token, email: email);
    await ensurePlanLocal('Free');
    await _setCvCompleteFlag(userId);

    if (!mounted) return;
    _goToMain();
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

  void _showError(String msg) => showErrorDialog(context, msg);

  void _goToMain() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainLayout()),
      );

  Future<void> ensurePlanLocal([String defaultPlan = 'Free']) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('plan_name');
    if (current == null || current.isEmpty) {
      await prefs.setString('plan_name', defaultPlan);
    }
  }

  Future<void> _saveSession({
    required String userId,
    required String token,
    required String email,
    String planName = 'Free',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('token', token);
    await prefs.setString('user_email', email);
    if (!prefs.containsKey('plan_name')) {
      await prefs.setString('plan_name', planName);
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
                const Text(
                  'Créez votre compte 👋',
                  style: TextStyle(
                      fontSize: 28, color: white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Inscrivez-vous et commencez à postuler aux offres d\'emploi !',
                  style: TextStyle(
                      fontSize: 18, color: gray, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInputField(
                          "Nom complet", "Entrez votre nom", _nameController),
                      const SizedBox(height: 15),
                      _buildInputField("Adresse e-mail", "Entrez votre e-mail",
                          _emailController),
                      if (_emailError != null) // <-- NEW
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _emailError!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Text('Mot de passe',
                              style: const TextStyle(
                                  fontSize: 17,
                                  color: white,
                                  fontWeight: FontWeight.w600)),
                          Expanded(
                              child: SizedBox(
                            width: 1,
                          ))
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildPasswordField(
                        hintText: "Entrez votre mot de passe",
                        controller: _passwordController,
                        errorText: _passwordError,
                        isVisible: _isPasswordVisible,
                        toggleVisibility:
                            _togglePasswordVisibility, // ← use the new method
                        onChanged: _checkPasswordStrength,
                      ),

                      const SizedBox(height: 15),
                      _buildPasswordField(
                        hintText: "Ré-entrez votre mot de passe",
                        controller: _confirmPasswordController,
                        errorText: _confirmPasswordError,
                        isVisible: _isConfirmPasswordVisible,
                        toggleVisibility:
                            _toggleConfirmPasswordVisibility, // ← your existing confirm toggle
                        onChanged: (_) {},
                      ),
                      if (_confirmPasswordError != null) // <-- NEW
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _confirmPasswordError!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
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
                      const SizedBox(height: 15),
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
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: _signUpWithGoogle,
                        child: Container(
                          width: MediaQuery.of(context).size.width,
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
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Image.asset(
                                  google,
                                  height: 35,
                                  width: 35,
                                ),
                              ),
                              Expanded(
                                  child: SizedBox(
                                width: 1,
                              )),
                              Padding(
                                padding: const EdgeInsets.only(right: 35),
                                child: Text(
                                  'Continuer avec Google',
                                  style: TextStyle(
                                      color: black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                  child: SizedBox(
                                width: 1,
                              )),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      const SizedBox(height: 15), // ← keep
                      FutureBuilder<bool>(
                        future: SignInWithApple.isAvailable(),
                        builder: (_, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.data == true) {
                            return SizedBox(
                              width: double.infinity,
                              height:
                                  MediaQuery.of(context).size.height * 0.075,
                              child: SignInWithAppleButton(
                                onPressed: _signInWithApple,
                                style: SignInWithAppleButtonStyle.white,
                                borderRadius: BorderRadius.circular(100),
                                iconAlignment: siwa.IconAlignment.left,
                              ),
                            );
                          }
                          return const SizedBox
                              .shrink(); // nothing shown on unsupported devices
                        },
                      ),
                      const SizedBox(height: 10),

                      const SizedBox(height: 20),
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

Widget _buildPasswordField({
  required String hintText,
  required TextEditingController controller,
  required String? errorText,
  required bool isVisible,
  required VoidCallback toggleVisibility,
  required ValueChanged<String> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: errorText == null ? gray : Colors.red,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  style: const TextStyle(color: white, fontSize: 16),
                  cursorColor: blue,
                  obscureText: !isVisible,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: gray, fontSize: 16),
                    hintMaxLines: 1,
                    border: InputBorder.none,
                  ),
                  onChanged: onChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: GestureDetector(
                  onTap: toggleVisibility,
                  child: Icon(
                    isVisible ? Icons.visibility_off : Icons.visibility,
                    color: gray,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 5, left: 25),
          child: Text(
            errorText,
            style: const TextStyle(color: Colors.red, fontSize: 14),
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
