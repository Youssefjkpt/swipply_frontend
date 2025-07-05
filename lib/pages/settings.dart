import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/about_us.dart';
import 'package:swipply/pages/gold_purchase_plan.dart';
import 'package:swipply/pages/notification.dart';
import 'package:swipply/pages/premium_purchase_plan.dart' hide LoadingBars;
import 'package:swipply/pages/profile.dart';
import 'package:swipply/pages/sign_in.dart';
import 'package:swipply/pages/welcoming_pages.dart';
import 'package:swipply/widgets/contact_us.dart';
import 'package:url_launcher/url_launcher.dart';

class MainSettings extends StatefulWidget {
  final ValueNotifier<int> currentTabIndex;
  const MainSettings({super.key, required this.currentTabIndex});

  @override
  State<MainSettings> createState() => _MainSettingsState();
}

class _MainSettingsState extends State<MainSettings> {
  String? _profilePhotoPath;
  String? _fullName;
  String _jobTitle = '';
  bool _isLoading = true;

  String? _sanitize(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return (s.isEmpty || s == '{}' || s == 'null') ? null : s;
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    if (id == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await http.get(Uri.parse('$BASE_URL_AUTH/users/$id'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _fullName = _sanitize(data['full_name']);
        _jobTitle = _sanitize(data['job_title']) ?? '';
        _profilePhotoPath = _sanitize(data['profile_photo_url']);
      }
    } catch (_) {
      // ignore silently – keep defaults
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() => _loadUser();

  @override
  Widget build(BuildContext context) {
    final name = _fullName ?? 'Mon nom';
    final title = _jobTitle.isNotEmpty ? _jobTitle : 'Intitulé de poste';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: black,
        body: Center(
          child: CircularProgressIndicator(color: white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: black,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: white,
        backgroundColor: black,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.08),
            Row(
              children: [
                const Expanded(child: SizedBox(width: 1)),
                Text(
                  'Paramètre',
                  style: TextStyle(
                      color: white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Expanded(child: SizedBox(width: 1)),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),
            GestureDetector(
              onTap: () {
                widget.currentTabIndex.value = 2;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: blackgraysettings,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                child: Row(
                  children: [
                    _avatar(),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              color: white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: const TextStyle(
                              color: white_gray,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: white, size: 18),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 41),
                  child: Text(
                    'Paramètre',
                    style: TextStyle(
                        color: white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                    child: SizedBox(
                  width: 1,
                ))
              ],
            ),
            SizedBox(
              height: 15,
            ),
            Container(
              decoration: BoxDecoration(
                color: blackgraysettings,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () {
                      widget.currentTabIndex.value = 2;
                    },
                    child: Container(
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(
                            Icons.person,
                            color: white,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            'Profile',
                            style: const TextStyle(
                                color: white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              color: white, size: 18),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: const Color.fromARGB(255, 77, 77, 77),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ApplicationsInProgressPage())),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Icon(
                          Icons.notifications,
                          color: white,
                        ),
                        const SizedBox(width: 15),
                        Text(
                          'Notifications',
                          style: const TextStyle(
                              color: white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios,
                            color: white, size: 18),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: const Color.fromARGB(255, 77, 77, 77),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => showLogoutOrDeleteDialog(context),
                    child: Container(
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(
                            Icons.logout,
                            color: white,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            'Se deconnecter',
                            style: const TextStyle(
                                color: white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              color: white, size: 18),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: const Color.fromARGB(255, 77, 77, 77),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SwipplyPremiumDetailsPage())),
                    child: Container(
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.diamond, color: white),
                          const SizedBox(width: 15),
                          Text(
                            'Ameliorer mon offre',
                            style: const TextStyle(
                                color: white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              color: white, size: 18),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
            SizedBox(
              height: 40,
            ),
            Container(
              decoration: BoxDecoration(
                color: blackgraysettings,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => AboutUsPage())),
                    child: Container(
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(
                            Icons.info,
                            color: white,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            'Qui sommes nous?',
                            style: const TextStyle(
                                color: white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              color: white, size: 18),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: const Color.fromARGB(255, 77, 77, 77),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _launchWhatsApp(),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Icon(
                          Icons.message,
                          color: white,
                        ),
                        const SizedBox(width: 15),
                        Text(
                          'Aide/FAQ',
                          style: const TextStyle(
                              color: white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios,
                            color: white, size: 18),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: const Color.fromARGB(255, 77, 77, 77),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => showConfirmDeleteAccountDialog(context),
                    child: Container(
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            'Supprimer le compte',
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              color: white, size: 18),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    if (_profilePhotoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: FadeInImage.assetNetwork(
          placeholder: progress, // animated spinner in assets
          image: '$BASE_URL_AUTH$_profilePhotoPath',
          height: 50,
          width: 50,
          fit: BoxFit.cover,
          imageErrorBuilder: (_, __, ___) => _defaultAvatar(),
        ),
      );
    }
    return _defaultAvatar();
  }

  Future showLoadingPopup(BuildContext context) {
    return showDialog(
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

  Future<void> _launchWhatsApp() async {
    final Uri uri = Uri.parse(
        "whatsapp://send?phone=33758819649&text=Bonjour%20Swipply%20Team");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // fallback to web link
      final fallbackUri =
          Uri.parse("https://wa.me/33758819649?text=Bonjour%20Swipply%20Team");
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("❌ Cannot launch WhatsApp via app or web.");
      }
    }
  }

  void hideLoadingPopup(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

// Ajoute ça dans la classe _ProfileState

  Future<void> _deleteAccount() async {
    // 1️⃣  Affiche le loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingPopup(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('token');

      if (jwt == null) throw Exception('JWT manquant dans SharedPreferences');

      // 2️⃣  Appel API
      final res = await http.delete(
        Uri.parse('$BASE_URL_AUTH/auth/delete-account'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      // 3️⃣  Succès
      if (res.statusCode == 204) {
        debugPrint('✅ Compte supprimé avec succès');
        await prefs.clear();

        if (!mounted) return;
        Navigator.pop(context); // ferme le loader
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => OnboardingScreen()),
          (_) => false,
        );
        return;
      }

      // 4️⃣  Réponse serveur ≠ 204  → on logge, on déclenche l’erreur
      debugPrint(
        '❌ Delete account — code ${res.statusCode}\nBody:\n${res.body}',
      );
      throw Exception('Erreur serveur (${res.statusCode})');
    } catch (e, stack) {
      // 5️⃣  Gestion d’erreur : on logge TOUT pour le debug
      debugPrint('❌ Exception deleteAccount: $e');
      debugPrintStack(stackTrace: stack);

      if (mounted) Navigator.pop(context); // ferme le loader

      // 6️⃣  Popup UX générique (pas de détails techniques pour l’utilisateur)
      showErrorDialog(
        context,
        'Suppression impossible',
        'Une erreur est survenue. Veuillez réessayer plus tard.',
      );
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

  Future<void> showLogoutOrDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color.fromARGB(255, 27, 27, 27),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            constraints: const BoxConstraints(minHeight: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFC107), size: 40),
                const SizedBox(height: 20),
                const Text(
                  "Déconnexion ou suppression",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Souhaitez-vous vous déconnecter ou supprimer votre compte ?",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFCCCCCC),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4C4C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          showConfirmDeleteAccountDialog(context);
                        },
                        child: const Text(
                          "Supprimer le compte",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C2C2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignIn()));
                        },
                        child: const Text(
                          "Se déconnecter",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showConfirmDeleteAccountDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color.fromARGB(255, 27, 27, 27),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            constraints: const BoxConstraints(minHeight: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFC107), size: 40),
                const SizedBox(height: 20),
                const Text(
                  "Confirmation requise",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFCCCCCC),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4C4C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteAccount();
                          // Later: handle delete account logic here
                        },
                        child: const Text(
                          "Supprimer",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _defaultAvatar() => Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Icon(Icons.person, color: black_gray, size: 28),
      );
}
