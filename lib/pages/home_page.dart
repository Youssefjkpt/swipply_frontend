// ignore_for_file: unused_field
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/job_categories.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/cv.dart';
import 'package:swipply/pages/job_description.dart';
import 'package:swipply/pages/notification.dart';
import 'package:swipply/pages/sign_in.dart';
import 'package:swipply/pages/subscriptions.dart';
import 'package:swipply/services/api_service.dart';
import 'package:swipply/widgets/category_container.dart';
import 'package:http/http.dart' as http;
import 'package:characters/characters.dart';

/// Returns true if [s] looks like an absolute http/https URL.
bool _looksLikeUrl(String s) {
  if (s.trim().isEmpty) return false;
  final uri = Uri.tryParse(s);
  return uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

String _initials(String raw) {
  final trimmed = raw.trim();

  // Nothing to work with → single “?” (or return '' if you prefer blank)
  if (trimmed.isEmpty) return 'FT';

  // Throw away the empty chunks that split() may create
  final parts =
      trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  if (parts.isEmpty) return 'FT';

  // Helper: first glyph of a word, works for composed characters
  String firstChar(String word) => word.characters.first;

  if (parts.length == 1) {
    final word = parts.first;
    // Pick the first *two* glyphs if the word is long enough, otherwise one.
    final take = word.characters.take(2).toList().join();
    return take.toUpperCase();
  }

  // Two or more words → first of first + first of last
  return (firstChar(parts.first) + firstChar(parts.last)).toUpperCase();
}

/* ───────────────────────── reusable info dialog ────────────────────────── */
class CompanyLogo extends StatelessWidget {
  const CompanyLogo(this.rawValue, {super.key});

  final String rawValue;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    final size = const Size.square(75);

    // Case 1: the string is (or at least looks like) a URL
    if (_looksLikeUrl(rawValue)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          rawValue,
          height: size.height,
          width: size.width,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported, size: 30),
        ),
      );
    }

    // Case 2: fallback “text logo”
    return Container(
      height: size.height,
      width: size.width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black, // <- background
        borderRadius: borderRadius,
      ),
      child: Text(
        _initials(rawValue),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white, // <- text colour
        ),
      ),
    );
  }
}

class _GenericInfoDialog extends StatelessWidget {
  const _GenericInfoDialog({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext ctx) {
    return Dialog(
      backgroundColor: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        constraints: const BoxConstraints(minHeight: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 44),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(body,
                style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onPrimary?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(primaryLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF2B2B2B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(secondaryLabel!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white70)),
                    ),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _swipeProgress = 0.0;
  List<String> _allCategoriesFromDB = [];
  final GlobalKey bellKey = GlobalKey();
  String? fullName, email, phone, resume, jobTitle;
  bool cvLoading = false;
  int _swipeCount = 0;
  int? _dailySwipeLimit;
  int _totalSwipesUsed = 0; // <-- Added to fix undefined name error
  int _bonusSwipes = 0; // Add to state
  void _runFlyingAnimation(Offset start, Offset end) {
    final overlay = Overlay.of(context, rootOverlay: false);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          AnimatedFlyingCircle(
            start: start,
            end: end,
            onComplete: () {
              Future.delayed(const Duration(seconds: 2), () {
                entry.remove(); // ✅ delayed removal
              });
            },
          ),
        ],
      ),
    );

    overlay.insert(entry);
  }

  Widget _buildGodCard({
    required IconData icon,
    required String title,
    required String value,
    required Color colorStart,
    required Color colorEnd,
    required Color iconBg,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.44,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [colorStart, colorEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 35,
            width: 35,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconBg.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.6),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> experiences = [],
      education = [],
      languages = [],
      interests = [],
      softSkills = [];
  List<dynamic> certificates = [], skillsAndProficiency = [];

  final CardSwiperController _controller = CardSwiperController();
  final Completer<GoogleMapController> _mapController = Completer();
  ValueNotifier<bool> isSwiping = ValueNotifier(false);
  final GlobalKey<_GradientSwapButtonState> cancelBtnKey = GlobalKey();
  final GlobalKey<_GradientSwapButtonState> rewindBtnKey = GlobalKey();
  final GlobalKey<_GradientSwapButtonState> likeBtnKey = GlobalKey();
  String? profileImageUrl;
  List<Map<String, dynamic>> jobs = [];
  bool isLoading = true;

  int _currentPage = 0;
  final Map<int, bool> _expandedMaps = {};
  int _currentIndex = 0; // Track the current card index
  bool _isMapLoading = true;
  void _goToNextPage() {
    setState(() {
      if (_currentPage < 2) {
        _currentPage++;
        _isMapLoading = true;

        if (_currentPage == 1) {
          cvLoading = true;
          _fetchUserProfile().then((_) {
            setState(() {
              cvLoading = false;
            });
          });
        }
      }
    });
  }

  void _goToPreviousPage() {
    if (_currentPage == 1) {
      setState(() {
        _currentPage = 0;
      });
    }
  }

  void _toggleMapSize(int index) {
    setState(() {
      if (!_expandedMaps.containsKey(index)) {
        _expandedMaps[index] = false; // Initialize if missing
      }
      _expandedMaps[index] = !_expandedMaps[index]!;
    });
  }

  List<String> _safeDecodeList(dynamic data) {
    if (data == null) return [];

    if (data is List) return List<String>.from(data.map((e) => e.toString()));

    try {
      final decoded = json.decode(data);
      if (decoded is List) return List<String>.from(decoded);
    } catch (_) {}

    return [];
  }

  Future<void> _recordFirstSwipeTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('swipe_first_ts')) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('swipe_first_ts', now);
    }
  }

  Future<bool> canSwipeJob(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');

    if (userId == null) return false;

    final response = await http.post(
      Uri.parse('$BASE_URL_AUTH/api/swipe-job'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'user_id': userId,
        'job_id': jobId,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    } else {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfileOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return null;

    final token = prefs.getString('token');

    final userRes = await http.get(
      Uri.parse('$BASE_URL_AUTH/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final empRes = await http.get(
      Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (userRes.statusCode == 200 && empRes.statusCode == 200) {
      final userData = json.decode(userRes.body);
      final empData = json.decode(empRes.body);

      return {
        'full_name': userData['full_name'],
        'address': userData['address'],
        'email': userData['email'],
        'phone': userData['phone'],
        'resume': empData['resume'],
        'experience': empData['experience'],
        'education': empData['education'],
        'languages': empData['languages'],
        'interests': empData['interests'],
        'soft_skills': empData['soft_skills'],
        'certificates': empData['certificates'],
        'skills_and_proficiency': empData['skills_and_proficiency'],
      };
    } else {
      return null;
    }
  }

  Future<bool> _checkCvComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('cv_complete') ?? false;
  }

  List<String> _safeDecodeStringifiedSet(dynamic data) {
    if (data == null || data.toString().isEmpty) return [];

    try {
      if (data is String) {
        final cleaned = data.trim();

        // Try manual pattern match if it's a fake JSON-like string without quotes
        if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
          final stripped =
              cleaned.substring(1, cleaned.length - 1); // remove braces
          return [stripped.trim().replaceAll(RegExp(r'^"|"$'), '')];
        }

        final decoded = json.decode(cleaned);
        if (decoded is Map) {
          return decoded.keys.map((k) => k.toString()).toList();
        } else if (decoded is List) {
          return List<String>.from(decoded.map((e) => e.toString()));
        } else {
          return [decoded.toString()];
        }
      } else if (data is Map) {
        return data.keys.map((k) => k.toString()).toList();
      } else if (data is List) {
        return List<String>.from(data.map((e) => e.toString()));
      }
    } catch (e) {}

    return [];
  }

  String? sanitizeField(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '{}' || str == 'null') return null;
    return str;
  }

  String? _planName;

  Future<void> showSwipeLimitReachedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color.fromARGB(255, 27, 27, 27),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            constraints: const BoxConstraints(minHeight: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    color: Color(0xFFFF4C4C), size: 40),
                const SizedBox(height: 20),
                const Text(
                  "Limite quotidienne atteinte",
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
                  "Améliorez votre offre pour bénéficier de plus de swipes.",
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
                          backgroundColor: const Color(0xFF00C2C2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const FullSubscriptionPage(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            "Voir l'offre",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 14),
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            "Annuler",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
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

  bool _canUndo = false;

// inside onUndo – just before `return true;`

  Future<void> showCustomCVDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color.fromARGB(255, 27, 27, 27),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            constraints: const BoxConstraints(minHeight: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded,
                    color: Color(0xFFFFC107), size: 40),
                const SizedBox(height: 20),
                const Text(
                  "Complétez votre CV",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Pour postuler ou personnaliser votre CV, veuillez terminer la configuration de votre profil.",
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
                          backgroundColor: const Color(0xFF25398A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CV()),
                          );
                        },
                        child: const Text("Aller au CV",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
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
                        child: const Text("Annuler",
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white70)),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  bool _canPersonalize = false;

  Future<void> _autoRegisterAndApply(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL_AUTH/api/auto-register-apply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'job_id': jobId,
        }),
      );

      if (response.statusCode == 200) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Application sent successfully.")),
        // );
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed: ${response.statusCode}")),
        // );
      }
    } catch (e) {}
  }

  // ...existing code...
  Future<void> _pullJobs({
    List<String> cats = const [],
    List<String> emp = const [],
    List<String> contr = const [],
    int? sinceH,
  }) async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    // Get list of already swiped job IDs
    final List<String> swipedJobIds =
        prefs.getStringList('swiped_job_ids') ?? [];

    print('Swiped job IDs: ${swipedJobIds.length}'); // Debug print

    try {
      if (userId != null) {
        jobs = await ApiService.fetchBestJobsForUser(
          userId: userId,
          n: 100,
          excludeJobIds: swipedJobIds,
          fastApiUrl: 'https://swipply-2ue1.onrender.com',
          baseUrlJobs: 'https://swipply-backend.onrender.com',
        );
        print('Fetched ${jobs.length} jobs after filtering'); // Debug print
      } else {
        jobs = [];
      }
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _currentIndex = 0;
        _expandedMaps.clear();
      });
    }
  }

// ...existing code...
  /* ───────────────────────────────────────────────────────────────
   Resets the swipe counter if its window (24 h or 7 d) is over.
   Also downgrades the plan to Free when the subscription expires.
   ───────────────────────────────────────────────────────────── */
  Future<void> _maybeResetSwipeCounters() async {
    final prefs = await SharedPreferences.getInstance();
    final plan = prefs.getString('plan_name') ?? 'Free';
    final winStart = prefs.getInt('swipe_window_ts') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = nowMs - winStart;

    final bool isFree = plan.toLowerCase() == 'free';
    final int windowMs = isFree
        ? 24 * 60 * 60 * 1000 // 24 h
        : 7 * 24 * 60 * 60 * 1000; // 7 d

    /* 1️⃣  reset the swipe counter when the window is finished */
    if (elapsedMs >= windowMs) {
      await prefs
        ..setInt('swipe_window_ts', nowMs)
        ..setInt('swipe_count', 0);
      if (mounted) setState(() => _swipeCount = 0);
    }

    /* 2️⃣  downgrade the plan after its real expiry date */
    final planEnd = prefs.getInt('plan_end_ts') ?? 0;
    if (planEnd > 0 && nowMs >= planEnd) {
      await prefs.setString('plan_name', 'Free');
      // the next call to `_fetchUserCapabilities()` will
      // pull fresh limits from the backend, but we keep UI in sync:
      if (mounted) setState(() => _planName = 'Free');
    }
  }

  /// Helper to recalculate _totalSwipesUsed on startup (swipe_count + bonus swipes used in window)
  Future<void> _recalculateTotalSwipesUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final int swipeCount = prefs.getInt('swipe_count') ?? 0;
    final int total = swipeCount;
    await prefs.setInt('total_swipes_used', total);
    if (mounted) setState(() => _totalSwipesUsed = total);
  }

  // Call this after fetching user capabilities (so _bonusSwipes is set)
// ...existing code...
  // Track if filters are active
  bool _filtersActive = false;
  List<String> _activeCategories = [];
  List<String> _activeEmployment = [];
  List<String> _activeContract = [];
  int? _activeSinceHours;

  // Call this to fetch jobs based on current filter state
  Future<void> _refreshJobs() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final List<String> swipedJobIds =
        prefs.getStringList('swiped_job_ids') ?? [];
    if (_filtersActive) {
      // Use filtered jobs
      jobs = await ApiService.fetchFilteredJobs(
        categories: _activeCategories,
        employmentTypes: _activeEmployment,
        contractTypes: _activeContract,
        sinceHours: _activeSinceHours,
        userId: userId,
      );
    } else {
      // Use best jobs
      if (userId != null) {
        jobs = await ApiService.fetchBestJobsForUser(
          userId: userId,
          n: 100,
          excludeJobIds: swipedJobIds,
          fastApiUrl: 'https://swipply-2ue1.onrender.com',
          baseUrlJobs: 'https://swipply-backend.onrender.com',
        );
      } else {
        jobs = [];
      }
    }
    setState(() {
      isLoading = false;
      _currentIndex = 0;
      _expandedMaps.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() => _planName = prefs.getString('plan_name'));
    });
    _maybeResetSwipeCounters();
    _fetchUserCapabilities().then((_) async {
      _filtersActive = false;
      await _refreshJobs();
      _fetchUserProfile();
      _loadCategories();
      _loadLocalSwipeCount();
    });
  }

// ...existing code...
  void _loadCategories() async {
    final raw = await ApiService.fetchFilteredJobs(); // unfiltered list
    if (!mounted) return;
    final set = <String>{};
    for (final j in raw) {
      set.addAll(List<String>.from(j['job_category'] ?? []));
    }
    setState(() => _allCategoriesFromDB = set.toList()..sort());
  }

  List<String> parsePostgresArray(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    String s = raw.toString().trim();
    if (s.startsWith('{') && s.endsWith('}')) {
      s = s.substring(1, s.length - 1);
    }
    if (s.isEmpty) return [];
    return s
        .split(RegExp(r','))
        .map((e) => e.trim().replaceAll(RegExp(r'^"|"$'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String? address;
  Future<void> _personalizeCv(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) {
      // not signed-in
      return showSignInRequiredDialog();
    }
    if (!await canPersonalizeLocally()) {
      // daily quota hit
      return _showPersonalizeQuotaDialog(() => _personalizeCv(jobId));
    }

    if (userId == null) return;

    try {
      setState(() => cvLoading = true);

      final response = await http.post(
        Uri.parse('$BASE_URL_AUTH/api/personalize-cv'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'job_id': jobId,
        }),
      );

      if (response.statusCode == 200) {
        final cvRes = await http.get(Uri.parse(
          '$BASE_URL_AUTH/api/personalized-cv?user_id=$userId&job_id=$jobId',
        ));

        if (cvRes.statusCode == 200) {
          await incrementLocalPersonalizeCount();
          final personalizedData = json.decode(cvRes.body);

          setState(() {
            resume = personalizedData['personalized_resume'] ?? resume;
            jobTitle = personalizedData['job_title'] ?? jobTitle;
            fullName = personalizedData['full_name'] ?? fullName;

            experiences = parsePostgresArray(personalizedData['experience']);
            education = parsePostgresArray(personalizedData['education']);
            softSkills = parsePostgresArray(personalizedData['soft_skills']);
            languages = parsePostgresArray(personalizedData['languages']);
            interests = parsePostgresArray(personalizedData['interests']);

            certificates =
                List<dynamic>.from(personalizedData['certificates'] ?? []);
            skillsAndProficiency = List<dynamic>.from(
                personalizedData['skills_and_proficiency'] ?? []);
          });

          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text("CV personalized successfully.")),
          // );
        } else {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text("Failed to load personalized CV.")),
          // );
          // DEFENSIVELY PARSE THE ERROR MESSAGE
          // …inside your cvRes.statusCode != 200 block…
          showStripeErrorPopup(
            context,
          );
        }
      } else if (response.statusCode == 403) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: const Color.fromARGB(255, 27, 27, 27),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              constraints: const BoxConstraints(minHeight: 200),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      color: Color(0xFFFF4C4C), size: 40),
                  const SizedBox(height: 20),
                  const Text(
                    "Upgrade pour débloquer",
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
                    "Limite quotidienne atteinte pour les CV personnalisés.\nUpgrade pour continuer la personnalisation.",
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
                            backgroundColor: const Color(0xFF00C2C2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const FullSubscriptionPage()));
                          },
                          child: const Text("Améliorer l'offre",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
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
                          child: const Text("Annuler",
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70)),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed: ${response.statusCode}")),
        // );
        // DEFENSIVELY PARSE THE ERROR MESSAGE
        showStripeErrorPopup(
          context,
        );
      }
    } catch (e) {
      //

      showStripeErrorPopup(
        context,
      );
    } finally {
      setState(() => cvLoading = false);
    }
  }

  Future<void> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final userRes = await http.get(Uri.parse('$BASE_URL_AUTH/users/$userId'));
    final empRes =
        await http.get(Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'));

    if (userRes.statusCode == 200 && empRes.statusCode == 200) {
      final userData = json.decode(userRes.body);
      final empData = json.decode(empRes.body);

      try {
        setState(() {
          final rawPath =
              userData['profile_photo_url']; // ✅ use the correct field
          if (rawPath != null && rawPath.toString().isNotEmpty) {
            profileImageUrl = rawPath; // ✅ already a full URL
          } else {
            profileImageUrl = null;
          }

          fullName = sanitizeField(userData['full_name']);
          jobTitle = sanitizeField(userData['job_title']);

          address = userData['address'];
          email = userData['email'];
          phone = userData['phone_number'];

          resume = empData['resume'];
          education = empData['education'] is List
              ? List<String>.from(empData['education'].map((e) => e.toString()))
              : _safeDecodeStringifiedSet(empData['education']);

          experiences = _safeDecodeStringifiedSet(empData['experience']);

          languages = _safeDecodeList(empData['languages']);
          interests = _safeDecodeList(empData['interests']);
          softSkills = _safeDecodeList(empData['soft_skills']);

          final rawCerts = empData['certificates'];
          certificates = rawCerts is List
              ? rawCerts
              : (rawCerts is Map ? rawCerts.values.toList() : []);
          final rawSkills = empData['skills_and_proficiency'];
          skillsAndProficiency = rawSkills is List
              ? rawSkills
              : (rawSkills is Map ? rawSkills.values.toList() : []);
        });
      } finally {
        if (mounted) {
          setState(() {
            cvLoading = false;
          });
        }
      }
    } else {}
  }

  int? _dailyPersonalizeLimit;
  bool _autoApply = false;
  Future<int> getLocalPersonalizeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('personalize_count') ?? 0;
  }

  Future<void> incrementLocalPersonalizeCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getLocalPersonalizeCount();
    await prefs.setInt('personalize_count', current + 1);
  }
// STATE

// Called once at startup (after your capabilities load)
  // DELETE _loadSwipeCount() completely
// ───────────────────────────────────

// ADD THIS local helper instead
  Future<int> _loadLocalSwipeCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('swipe_count') ?? 0;
    setState(() => _swipeCount = count);
    return count;
  }

  Future<bool> canPersonalizeLocally() async {
    return _dailyPersonalizeLimit != null &&
        await getLocalPersonalizeCount() < _dailyPersonalizeLimit!;
  }

// 1️⃣  Sign-in required
  Future<void> showSignInRequiredDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _GenericInfoDialog(
        icon: Icons.login_rounded,
        iconColor: const Color(0xFF00C2C2),
        title: 'Connecte-toi pour continuer',
        body:
            'Tu dois être connecté pour swiper à droite ou personnaliser ton CV.',
        primaryLabel: 'Se connecter',
        onPrimary: () {
          Navigator.pushReplacement(
            context, // outer context!
            MaterialPageRoute(builder: (_) => const SignIn()),
          );
        },
      ),
    );
  }

// 2️⃣  Daily personalisation quota hit
  Future<void> _showPersonalizeQuotaDialog(VoidCallback _proceedAnyway) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _GenericInfoDialog(
        icon: Icons.hourglass_bottom_rounded,
        iconColor: const Color(0xFFFFC107),
        title: 'Quota de personnalisation atteint',
        body:
            'Même personnalisé, tu ne pourras pas postuler aujourd’hui.\nContinuer quand même ?',
        primaryLabel: 'Personnaliser quand même',
        secondaryLabel: 'Plus tard',
        onPrimary: () {
          Navigator.pop(context);
          _proceedAnyway(); // call real fn
        },
      ),
    );
  }

  /// returns the max #swipes allowed in *the current window*
  void _openGoldPlanFast() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const FullSubscriptionPage(),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1), // starts fully off-screen bottom
            end: Offset.zero, // ends at normal position
          ).animate(CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic, // quick, smooth curve
          ));
          return SlideTransition(position: slide, child: child);
        },
      ),
    );
  }

  Future<void> _fetchUserCapabilities() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');
    if (userId == null) return;
    final res = await http.get(
      Uri.parse('$BASE_URL_AUTH/api/user-capabilities/$userId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        final plan = (data['plan_name'] as String?) ?? 'Free';
        final planEnds = data['plan_end_ts'] as int?;
        _planName = data['plan_name'] as String?;
        _dailySwipeLimit = data['daily_swipe_limit'];
        _bonusSwipes = data['bonus_swipes'] ?? 0;
        _canPersonalize = data['can_personalize_cv'];
        prefs
          ..setString('plan_name', plan)
          ..setInt('plan_end_ts', planEnds ?? 0);
        _autoApply = (data['has_auto_apply'] as bool?) ?? false;
        _dailyPersonalizeLimit = data['daily_personalize_limit'];
      });
      debugPrint('📝 Plan: $_planName');
      debugPrint('📝 Daily swipe limit: $_dailySwipeLimit ');
      debugPrint('📝 Daily CV‐personalize limit: $_dailyPersonalizeLimit');
      debugPrint('📝 Auto‐apply enabled: $_autoApply');
      debugPrint('📝 Can personalize CV: $_canPersonalize');
      debugPrint('📝 Bonus swipes: $_bonusSwipes');
    }
  }

  Future<void> _decrementBonusSwipes() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;
    final res = await http.post(
      Uri.parse('$BASE_URL_AUTH/api/decrement-bonus-swipes/$userId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        _bonusSwipes = data['bonus_swipes'] ?? (_bonusSwipes - 1);
      });
    } else {
      setState(() {
        if (_bonusSwipes > 0) _bonusSwipes--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: black_gray,
          elevation: 0,
          title: const Text(
            'Swipply',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          centerTitle: false,
          actions: [
            RingingBellButton(bellKey: bellKey),
            IconButton(
              icon: const Icon(CupertinoIcons.slider_horizontal_3,
                  color: Colors.white),
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => JobFilterSheet(
                    allCategories: _allCategoriesFromDB,
                    onApply: (
                        {required categories,
                        required employment,
                        required contract,
                        required sinceHours}) async {
                      setState(() {
                        _filtersActive = true;
                        _activeCategories = categories;
                        _activeEmployment = employment;
                        _activeContract = contract;
                        _activeSinceHours = sinceHours;
                      });
                      await _refreshJobs();
                    },
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : jobs.isEmpty
                ? const Center(
                    child: Text("Aucune offre trouvée.",
                        style: TextStyle(color: Colors.white)))
                : Stack(
                    children: [
                      Column(children: [
                        const SizedBox(height: 5),
                        Expanded(
                            child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    _swipeProgress = (details.delta.dx.abs() /
                                            MediaQuery.of(context).size.width)
                                        .clamp(0.0, 1.0);
                                  });
                                },
                                onPanEnd: (_) {
                                  setState(() {
                                    _swipeProgress = 0.0;
                                  });
                                },
                                child: CardSwiper(
                                  controller: _controller,
                                  cardsCount: jobs.length,
                                  onSwipe: (int previousIndex, int? targetIndex,
                                      CardSwiperDirection direction) async {
                                    await _maybeResetSwipeCounters();
                                    await _loadLocalSwipeCount();
                                    if (!await _checkCvComplete()) {
                                      await showCustomCVDialog();
                                      return false;
                                    }
                                    if (direction ==
                                        CardSwiperDirection.right) {
                                      final totalAllowed =
                                          (_dailySwipeLimit ?? 0) +
                                              (_bonusSwipes);
                                      if ((_swipeCount +
                                              (_bonusSwipes > 0 ? 0 : 1)) >=
                                          totalAllowed) {
                                        await showSwipeLimitReachedDialog(
                                            context);
                                        return false;
                                      }
                                      final jobId =
                                          jobs[previousIndex]['job_id'];
                                      Future.microtask(() async {
                                        if (_bonusSwipes > 0) {
                                          await _decrementBonusSwipes();
                                        } else {
                                          await _postSwipe(jobId,
                                              action: 'right');
                                          await _loadLocalSwipeCount();
                                          _autoRegisterAndApply(jobId);
                                          await _recordFirstSwipeTimestamp();
                                        }
                                      });
                                      setState(() {
                                        _currentIndex =
                                            targetIndex ?? _currentIndex;
                                        _currentPage = 0;
                                      });
                                    }
                                    if (direction == CardSwiperDirection.left) {
                                      final jobId =
                                          jobs[previousIndex]['job_id'];
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      Future.microtask(() =>
                                          _postSwipe(jobId, action: 'left'));
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        cancelBtnKey.currentState
                                            ?.triggerSwapExternally();
                                      });
                                    } else if (direction ==
                                        CardSwiperDirection.right) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        final RenderBox cardBox = likeBtnKey
                                            .currentContext!
                                            .findRenderObject() as RenderBox;
                                        final Offset start =
                                            cardBox.localToGlobal(Offset.zero);
                                        final RenderBox notifBox = bellKey
                                            .currentContext!
                                            .findRenderObject() as RenderBox;
                                        final Offset end =
                                            notifBox.localToGlobal(
                                                const Offset(12, 12));
                                        _runFlyingAnimation(start, end);
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        likeBtnKey.currentState
                                            ?.triggerSwapExternally();
                                      });
                                    }
                                    setState(() {
                                      _currentIndex =
                                          targetIndex ?? _currentIndex;
                                      _currentPage = 0;
                                      _expandedMaps.clear();
                                    });
                                    _canUndo = true;
                                    return true;
                                  },
                                  onUndo: (int? previousIndex,
                                      int restoredIndex,
                                      CardSwiperDirection direction) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      rewindBtnKey.currentState
                                          ?.triggerSwapExternally();
                                    });
                                    setState(() {
                                      _currentIndex = restoredIndex;
                                      _currentPage = 0;
                                      _expandedMaps.clear();
                                    });
                                    _canUndo = false;
                                    return true;
                                  },
                                  numberOfCardsDisplayed:
                                      max(1, min(2, jobs.length)),
                                  allowedSwipeDirection:
                                      const AllowedSwipeDirection.only(
                                    left: true,
                                    right: true,
                                  ),
                                  padding: EdgeInsets.zero,
                                  cardBuilder: (context, index,
                                      percentThresholdX, percentThresholdY) {
                                    final double swipeProgress =
                                        (percentThresholdX.abs() / 100)
                                            .clamp(0.0, 1.0);
                                    final double easedProgress =
                                        (swipeProgress / 5).clamp(0.0, 1.0);

                                    final bool isCurrentCard =
                                        index == _currentIndex;
                                    final bool isNextCard =
                                        index == (_currentIndex + 1);
                                    final bool isPreviousCard =
                                        index == (_currentIndex - 1);

                                    final double currentOffset = isCurrentCard
                                        ? -130 * easedProgress
                                        : 0;
                                    final double currentOpacity = isCurrentCard
                                        ? 1.0 - easedProgress
                                        : 1.0;

                                    final double nextOffset = isNextCard
                                        ? (-220 + 220 * easedProgress)
                                        : -220;
                                    final double nextOpacity =
                                        isNextCard ? easedProgress : 0.0;

                                    final double prevOffset = isPreviousCard
                                        ? (-220 + 220 * easedProgress)
                                        : -220;
                                    final double prevOpacity =
                                        isPreviousCard ? easedProgress : 0.0;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        if (isPreviousCard)
                                          Positioned(
                                            bottom: -40,
                                            left: 0,
                                            right: 0,
                                            child: Transform.translate(
                                              offset: Offset(0, prevOffset),
                                              child: Opacity(
                                                opacity: prevOpacity,
                                                child: Center(
                                                  child: Container(
                                                    height: 80,
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.9,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color.fromARGB(
                                                              255, 24, 24, 24),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (isNextCard)
                                          Positioned(
                                            bottom: -40,
                                            child: Transform.translate(
                                              offset: Offset(0, nextOffset),
                                              child: Opacity(
                                                opacity: nextOpacity,
                                                child: Center(
                                                  child: Container(
                                                    height: 80,
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.9,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color.fromARGB(
                                                              255, 24, 24, 24),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (isCurrentCard)
                                          Positioned(
                                            bottom: 25,
                                            left: 0,
                                            right: 0,
                                            child: Transform.translate(
                                              offset: Offset(0, currentOffset),
                                              child: Opacity(
                                                opacity: currentOpacity,
                                                child: Center(
                                                  child: Container(
                                                    height: 100,
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.9,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color.fromARGB(
                                                              255, 24, 24, 24),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        GestureDetector(
                                          onTapDown: (details) {
                                            final screenWidth =
                                                MediaQuery.of(context)
                                                    .size
                                                    .width;
                                            if (_currentPage == 0 &&
                                                details.localPosition.dx >
                                                    screenWidth / 2) {
                                              _goToNextPage();
                                            } else if (_currentPage == 1 &&
                                                details.localPosition.dx <
                                                    screenWidth / 2) {
                                              _goToPreviousPage();
                                            }
                                          },
                                          child: _currentPage == 0
                                              ? Transform.scale(
                                                  scale: 1,
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            bottom: 45),
                                                    child: _buildJobCard(index),
                                                  ),
                                                )
                                              : _buildCvPreview(index),
                                        ),
                                      ],
                                    );
                                  },
                                ))),
                        const SizedBox(
                          height: 20,
                        )
                      ]),
                      _buildActionButtons(),
                    ],
                  ));
  }

  Widget _buildJobCard(int index) {
    bool isCurrentCard = index == _currentIndex;
    final String salary = jobs[index]["salary"] ?? "Non précisé";
    final String contractType = jobs[index]["contract_type"] ?? "Non spécifié";

    return Stack(
      children: [
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 1,
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                if (isCurrentCard)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.of(context).size.height * 0.35,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [white, white],
                        ),
                      ),
                    ),
                  ),
                // Job Image
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.of(context).size.height * 0.3,
                            ),
                            width: double.infinity,
                            child: Image.network(
                              jobs[index]["company_background_url"] ?? '',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(welcome_img, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: MediaQuery.of(context).size.height * 0.16,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color.fromARGB(255, 255, 255, 255),
                                    Color.fromARGB(200, 255, 255, 255),
                                    Color.fromARGB(100, 255, 255, 255),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),

                // Text overlay
              ],
            ),
          ),
        ),
        _buildPageIndicator(),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.16,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CompanyLogo(jobs[index]['company_logo_url'] ?? ''),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  jobs[index]["title"] ?? "Titre indisponible",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  jobs[index]["company_name"] ?? "France Travail",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (jobs[index]["category_chip"] != null &&
                          jobs[index]["category_chip"] is List &&
                          jobs[index]["category_chip"].isNotEmpty)
                        ...jobs[index]["category_chip"]
                            .take(5)
                            .map<Widget>(
                                (chip) => CategoryChip(label: chip.toString()))
                            .toList()
                      else ...[
                        CategoryChip(
                            label: jobs[index]["employment_type"] ?? "Inconnu"),
                        CategoryChip(
                            label: jobs[index]["contract_type"] ?? "Inconnu"),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGodCard(
                      icon: Icons.attach_money_rounded,
                      title: 'Salaire',
                      value: salary,
                      colorStart: const Color(0xFFDCF8FF),
                      colorEnd: const Color(0xFFEFF9FC),
                      iconBg: const Color(0xFFB3E5FC),
                    ),
                    _buildGodCard(
                      icon: Icons.schedule,
                      title: 'Contrat',
                      value: contractType,
                      colorStart: const Color(0xFFE8EAF6),
                      colorEnd: const Color(0xFFF1F2FA),
                      iconBg: const Color(0xFFC5CAE9),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 15),
                      child: Text(
                        'Description',
                        style: TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ),
                    Expanded(
                        child: SizedBox(
                      width: 1,
                    ))
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    jobs[index]["description"] ?? "Inconnu",
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      letterSpacing: 0.1,
                      color: Colors.black.withOpacity(0.75),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
        if (isCurrentCard)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.15,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color.fromARGB(255, 255, 255, 255), // solid white
                    Color.fromARGB(240, 255, 255, 255), // slightly less opaque
                    Color.fromARGB(220, 255, 255, 255), // even lighter
                    Color.fromARGB(0, 255, 255, 255), // fully transparent
                  ],
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            ),
          ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Listener(
            onPointerDown: (_) =>
                setState(() => _disableScrollForDetails = true),
            onPointerUp: (_) =>
                setState(() => _disableScrollForDetails = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (index < jobs.length) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobInformations(job: jobs[index]),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Voir les détails',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: const Icon(
                        CupertinoIcons.chevron_up,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _disableScrollForDetails = false;

  Widget _buildCvPreview(int index) {
    return Stack(
      children: [
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.35,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 24, 24, 24),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 45),
          height: MediaQuery.of(context).size.height * 0.92,
          width: double.infinity,
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: cvLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20)),
                          color: Color.fromARGB(255, 37, 57, 138)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                          ),
                          ClipOval(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              child: profileImageUrl != null &&
                                      profileImageUrl!.isNotEmpty
                                  ? Image.network(
                                      profileImageUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) {
                                        return const Icon(Icons.person,
                                            color: Colors.white, size: 34);
                                      },
                                    )
                                  : const Icon(Icons.person,
                                      color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text(
                            'Coordonnées',
                            style: TextStyle(
                                color: white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.28,
                            height: 1.5,
                            decoration: const BoxDecoration(color: white),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 10),
                              const Icon(Icons.phone, color: white, size: 18),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  phone ?? 'Aucun téléphone',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const SizedBox(width: 10),
                              const Icon(Icons.mail, color: white, size: 18),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  email ?? 'Aucun e-mail',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          education.isNotEmpty
                              ? ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.of(context).size.height *
                                            0.1, // your desired cap
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: education.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 10),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ',
                                                  style: TextStyle(
                                                      color: white,
                                                      fontSize: 12)),
                                              Expanded(
                                                child: Text(item,
                                                    style: const TextStyle(
                                                        color: white,
                                                        fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                )
                              : const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    ' Aucune formation',
                                    style:
                                        TextStyle(color: white, fontSize: 12),
                                  ),
                                ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text(
                            'Soft skills',
                            style: TextStyle(
                                color: white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.28,
                            height: 1.5,
                            decoration: const BoxDecoration(color: white),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          softSkills.isNotEmpty
                              ? SizedBox(
                                  height: MediaQuery.of(context).size.height *
                                      0.12, // Adjust the height as needed
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: softSkills.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 10),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ',
                                                  style: TextStyle(
                                                      color: white,
                                                      fontSize: 12)),
                                              Expanded(
                                                child: Text(item,
                                                    style: const TextStyle(
                                                        color: white,
                                                        fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                )
                              : const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'Aucune compétence',
                                    style:
                                        TextStyle(color: white, fontSize: 12),
                                  ),
                                )
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (fullName != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 35, bottom: 4, left: 20, right: 20),
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  fullName!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: black,
                                  ),
                                ),
                              ),
                            ),
                          if (jobTitle != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 5, left: 20, right: 20),
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  jobTitle!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: white_gray,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Container(
                              width: 60,
                              height: 4,
                              color: const Color.fromARGB(255, 37, 57, 138),
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          const Text(
                            'Résumé',
                            style: TextStyle(
                                color: Color.fromARGB(255, 37, 57, 138),
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.5,
                            height: 1.5,
                            decoration: const BoxDecoration(
                                color: Color.fromARGB(255, 37, 57, 138)),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.15,
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: SingleChildScrollView(
                              child: Text(
                                (resume ?? 'Aucun résumé ajouté'),
                                style: const TextStyle(
                                  color: white_gray,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text(
                            'Expérience',
                            style: TextStyle(
                              color: Color.fromARGB(255, 37, 57, 138),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.5,
                            height: 1.5,
                            color: const Color.fromARGB(255, 37, 57, 138),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.25,
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: experiences.isNotEmpty
                                ? SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: experiences.map((item) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ',
                                                  style: TextStyle(
                                                      color: white_gray,
                                                      fontSize: 12)),
                                              Expanded(
                                                child: Text(
                                                  item,
                                                  style: const TextStyle(
                                                    color: white_gray,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  )
                                : const Text(
                                    'Aucune expérience',
                                    style: TextStyle(
                                        color: white_gray, fontSize: 12),
                                  ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
        ),
        _buildPageIndicator(),
        PulseButton(
          onPressed: () async {
            if (!_canPersonalize) {
              // you already wrote a dialog for this
              return showCustomCVDialog();
            }
            await _personalizeCv(jobs[index]['job_id']);
          },
        ),
        Positioned(
          bottom: 160,
          right: 20,
          child: GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const CV())),
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(100)),
                child: const Center(
                  child: Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              )),
        )
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Positioned(
      top: 15, // Move to the top of the card
      left: 0, // Align with the card
      right: 0, // Ensure full width
      child: SizedBox(
        width: MediaQuery.of(context).size.width, // Enforce width constraints
        child: Row(
          children: [
            const Expanded(
                child: SizedBox(width: 1)), // Add space before indicators
            Container(
              width: MediaQuery.of(context).size.width * 0.44,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                  color: _currentPage == 0
                      ? Colors.black
                      : const Color.fromARGB(97, 0, 0, 0),
                  borderRadius: BorderRadius.circular(5),
                  border: _currentPage == 0
                      ? Border.all(color: white, width: 0.5)
                      : Border.all(color: black, width: 0.5)),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.44,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                  color: _currentPage == 1
                      ? Colors.black
                      : const Color.fromARGB(97, 0, 0, 0),
                  borderRadius: BorderRadius.circular(5),
                  border: _currentPage == 0
                      ? Border.all(color: white, width: 0.5)
                      : Border.all(color: black, width: 0.5)),
            ),

            const Expanded(
                child: SizedBox(width: 1)), // Add space after indicators
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GradientSwapButton(
            key: cancelBtnKey,
            icon: CupertinoIcons.xmark,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF4C4C), Color.fromARGB(255, 255, 0, 170)],
            ),
            size: 60,
            onPressed: () {
              cancelBtnKey.currentState?.triggerSwapExternally();
              Future.delayed(const Duration(milliseconds: 150), () {
                final currentJob = jobs[_currentIndex];
                final jobId = currentJob['job_id'];
                _controller.swipe(CardSwiperDirection.left);
                Future.microtask(() => _postSwipe(jobId, action: 'left'));
              });
            },
          ),
          const SizedBox(width: 20),
          GradientSwapButton(
            key: rewindBtnKey,
            icon: Icons.replay,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFF00), Color(0xFFFFD700)],
            ),
            size: 50,
            onPressed: () {
              final bool isFree = (_planName ?? '').toLowerCase() == 'free' ||
                  _planName == null;
              if (isFree) {
                // ← only block when FREE
                _openGoldPlanFast(); //   show upgrade
                return;
              }
              // ② Premium but already rewound once → do nothing
              if (!_canUndo) return;

              // ③ Allowed: play animation & undo exactly one card
              rewindBtnKey.currentState?.triggerSwapExternally();
              Future.delayed(const Duration(milliseconds: 150), () {
                _controller.undo();
              });
            },
            addIconBorder: true,
          ),
          const SizedBox(width: 20),
          GradientSwapButton(
            key: likeBtnKey,
            icon: Icons.favorite,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF90EE90), Color(0xFF00B300)],
            ),
            size: 60,
            onPressed: () async {
              final currentJob = jobs[_currentIndex];
              final jobId = currentJob['job_id'];
              void runFlyingAnimation(Offset start, Offset end) {
                final overlay = Overlay.of(context, rootOverlay: false);
                late OverlayEntry entry;

                entry = OverlayEntry(
                  builder: (context) => Stack(
                    children: [
                      AnimatedFlyingCircle(
                        start: start,
                        end: end,
                        onComplete: () {
                          Future.delayed(const Duration(milliseconds: 1000),
                              () {
                            entry.remove(); // ✅ delayed removal
                          });
                        },
                      ),
                    ],
                  ),
                );

                overlay.insert(entry);
              }

              if (!await _checkCvComplete()) {
                await showCustomCVDialog();
                return;
              }

              await _loadLocalSwipeCount();
              if ((await SharedPreferences.getInstance())
                      .getString('user_id') ==
                  null) {
                return showSignInRequiredDialog();
              }

              likeBtnKey.currentState?.triggerSwapExternally();
              Future.delayed(const Duration(milliseconds: 150), () {
                _controller.swipe(CardSwiperDirection.right);
              });
              await _autoRegisterAndApply(jobId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _postSwipe(String jobId, {required String action}) async {
    await http.post(
      Uri.parse('$BASE_URL_AUTH/api/swipe-job'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': (await SharedPreferences.getInstance()).getString('user_id'),
        'job_id': jobId,
        'action': action,
      }),
    );
    if (action == 'right') {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getInt('swipe_count') ?? 0;
      await prefs.setInt('swipe_count', local + 1);
      setState(() => _swipeCount = local + 1);
      await _recordFirstSwipeTimestamp();
    }
  }
}

void showStripeErrorPopup(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierLabel: "stripeError",
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => const SafeArea(
      child: _StripeErrorContent(), // ← no parameter anymore
    ),
    transitionBuilder: (_, a1, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: child),
  );
}

class _StripeErrorContent extends StatelessWidget {
  const _StripeErrorContent({super.key});

  @override
  Widget build(BuildContext ctx) {
    return Center(
      child: Container(
        width: MediaQuery.of(ctx).size.width * 0.80,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1) Bigger Lottie (fits width while respecting aspect ratio)
            SizedBox(
              height: 130, // ← adjust to any size you want
              width: 130,
              child: Lottie.asset(
                errorBox, // your asset constant / path
                fit: BoxFit.contain,
              ),
            ),

            // 2) Friendly headline
            const Text(
              "Oups! Personnalisation échoué",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: null,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),

            // 3) Short explanatory sentence – always the same
            const Text(
              "Nous n'avons pas pu personnaliser votre CV. Merci de retenter ultérieurement.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontFamily: null,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 28),

            // 4) Close button
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Fermer",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: null,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 20,
            )
          ],
        ),
      ),
    );
  }
}

class GradientSwapButton extends StatefulWidget {
  final IconData icon;
  final LinearGradient gradient;
  final double size;
  final VoidCallback onPressed;
  final bool addIconBorder;

  const GradientSwapButton({
    super.key,
    required this.icon,
    required this.gradient,
    required this.size,
    required this.onPressed,
    this.addIconBorder = false,
  });

  @override
  State<GradientSwapButton> createState() => _GradientSwapButtonState();
}

class _GradientSwapButtonState extends State<GradientSwapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _gradientOpacity;
  bool _isAnimating = false;

  void triggerSwapExternally() {
    if (!_isAnimating) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _isAnimating = false);
        } else if (status == AnimationStatus.forward) {
          setState(() => _isAnimating = true);
        }
      });

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 80),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _gradientOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildIcon(Color iconColor) {
    return Icon(
      widget.icon,
      size: widget.size * 0.6,
      color: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final showGradientContainer = _gradientOpacity.value > 0;
        final showIconGray = _gradientOpacity.value > 0.5;

        final decoration = BoxDecoration(
          shape: BoxShape.circle,
          color: showGradientContainer ? null : black_gray,
          gradient: showGradientContainer ? widget.gradient : null,
        );

        final iconWidget = showIconGray
            ? _buildIcon(black_gray)
            : ShaderMask(
                shaderCallback: (bounds) {
                  return widget.gradient.createShader(
                    Rect.fromLTWH(0, 0, widget.size, widget.size),
                  );
                },
                blendMode: BlendMode.srcIn,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildIcon(Colors.white),
                    if (widget.addIconBorder)
                      _buildIcon(const Color(0xFFFFD700)),
                  ],
                ),
              );

        return GestureDetector(
          onTap: () {
            if (!_isAnimating) {
              widget.onPressed();
              _controller.forward(from: 0.0);
            }
          },
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: decoration,
              child: Center(child: iconWidget),
            ),
          ),
        );
      },
    );
  }
}

class JobFilterSheet extends StatefulWidget {
  final List<String> allCategories;
  final void Function({
    required List<String> categories,
    required List<String> employment,
    required List<String> contract,
    required int? sinceHours,
  }) onApply;

  const JobFilterSheet({
    super.key,
    required this.allCategories,
    required this.onApply,
  });

  @override
  State<JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends State<JobFilterSheet> {
  final _search = TextEditingController();
  final Set<String> _selCat = {};
  final Set<String> _selEmp = {};
  final Set<String> _selContr = {};
  int? _sinceH;

  static const empTypes = [
    'Temps plein',
    'Temps partiel',
    'Stage',
    'Alternance',
    'Freelance',
    'Autre'
  ];
  static const contrTypes = [
    'CDI',
    'CDD',
    'Stage',
    'Alternance',
    'Freelance',
    'Autre'
  ];
  static const recencyOpt = [null, 12, 24, 48, 168];

  Widget _chip(String label, bool sel, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? blue : black_gray,
            borderRadius: BorderRadius.circular(100),
            border: sel ? null : Border.all(color: white_gray),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: sel ? black : white_gray,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Accent-insensitive query
    String _norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');

    final String query = _norm(_search.text);
    final cats = query.isEmpty
        ? kJobCategoryKeywords.keys.take(8).toList() // default suggestions
        : kKeywordToCategory.entries // synonym lookup
            .where((e) => e.key.contains(query))
            .map((e) => e.value)
            .toSet() // unique
            .take(8)
            .toList();

    return WillPopScope(
        onWillPop: () async {
          widget.onApply(
            categories: _selCat.toList(),
            employment: _selEmp.toList(),
            contract: _selContr.toList(),
            sinceHours: _sinceH,
          );
          return true;
        },
        child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.6,
            expand: false,
            builder: (_, scroll) => GestureDetector(
                  onTap: () =>
                      FocusScope.of(context).unfocus(), // hide keyboard
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context)
                          .viewInsets
                          .bottom, // lift above KB
                    ),
                    child: Container(
                      // ← the original

                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: blue_gray,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(25)),
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 80,
                              height: 7,
                              decoration: BoxDecoration(
                                color: white_gray,
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Filtrer les offres',
                            style: TextStyle(
                                color: white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: black_gray,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: white_gray),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _search,
                                    style: const TextStyle(color: white),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintText: 'Catégorie…',
                                      hintStyle: TextStyle(color: white_gray),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scroll,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: cats
                                        .map((c) => _chip(
                                              c,
                                              _selCat.contains(c),
                                              () => setState(() {
                                                _selCat.contains(c)
                                                    ? _selCat.remove(c)
                                                    : _selCat.add(c);
                                              }),
                                            ))
                                        .toList(),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child:
                                        Divider(color: white_gray, height: 1),
                                  ),
                                  const Text(
                                    'Type de contrat',
                                    style: TextStyle(
                                        color: white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: contrTypes
                                        .map((c) => _chip(
                                              c,
                                              _selContr.contains(c),
                                              () => setState(() {
                                                _selContr.contains(c)
                                                    ? _selContr.remove(c)
                                                    : _selContr.add(c);
                                              }),
                                            ))
                                        .toList(),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child:
                                        Divider(color: white_gray, height: 1),
                                  ),
                                  const Text(
                                    'Temps de travail',
                                    style: TextStyle(
                                        color: white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: empTypes
                                        .map((e) => _chip(
                                              e,
                                              _selEmp.contains(e),
                                              () => setState(() {
                                                _selEmp.contains(e)
                                                    ? _selEmp.remove(e)
                                                    : _selEmp.add(e);
                                              }),
                                            ))
                                        .toList(),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child:
                                        Divider(color: white_gray, height: 1),
                                  ),
                                  const Text(
                                    'Récence',
                                    style: TextStyle(
                                        color: white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: recencyOpt
                                        .map((h) => _chip(
                                              h == null ? 'Tout' : '≤ $h h',
                                              _sinceH == h,
                                              () => setState(() => _sinceH = h),
                                            ))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 42),
                            child: GestureDetector(
                              onTap: () {
                                widget.onApply(
                                  categories: _selCat.toList(),
                                  employment: _selEmp.toList(),
                                  contract: _selContr.toList(),
                                  sinceHours: _sinceH,
                                );
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: const Center(
                                  child: Text(
                                    'Appliquer les filtres',
                                    style: TextStyle(
                                        color: white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )));
  }
}

class PulseButton extends StatefulWidget {
  final VoidCallback onPressed;
  const PulseButton({super.key, required this.onPressed});

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 20,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          double value = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft aura
              Container(
                width: 60 + (value * 20), // smaller range
                height: 60 + (value * 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00C2C2).withOpacity(1 - value),
                ),
              ),

              // Actual button
              GestureDetector(
                onTap: widget.onPressed,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF00C2C2),
                        Color(0xFF25398A), // dark tech blue
                      ],
                      center: Alignment.center,
                      radius: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C2C2).withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_fix_high,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RingingBellButton extends StatefulWidget {
  final GlobalKey bellKey;
  const RingingBellButton({required this.bellKey, super.key});
  @override
  _RingingBellButtonState createState() => _RingingBellButtonState();
}

class _RingingBellButtonState extends State<RingingBellButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  void _ringBell() {
    try {
      _controller.forward(from: 0).then((_) => _controller.reverse());
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ApplicationsInProgressPage()),
      );
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.rotate(
          angle:
              0.5 * (1 - _controller.value) * sin(_controller.value * pi * 4),
          child: child,
        );
      },
      child: IconButton(
        key: widget.bellKey,
        icon: const Icon(CupertinoIcons.bell, color: Colors.white),
        onPressed: _ringBell,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AnimatedFlyingCircle extends StatefulWidget {
  final Offset start;
  final Offset end;
  final VoidCallback onComplete;

  const AnimatedFlyingCircle({
    super.key,
    required this.start,
    required this.end,
    required this.onComplete,
  });

  @override
  _AnimatedFlyingCircleState createState() => _AnimatedFlyingCircleState();
}

class _AnimatedFlyingCircleState extends State<AnimatedFlyingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward().whenComplete(widget.onComplete);

    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  Offset _calculateParabolicOffset(double t) {
    final p0 = widget.start;
    final p2 = widget.end.translate(10, -5); // small shift to right of icon

    final control = Offset(
      (p0.dx + p2.dx) / 2,
      min(p0.dy, p2.dy) - 120,
    );

    final x = pow(1 - t, 2) * p0.dx +
        2 * (1 - t) * t * control.dx +
        pow(t, 2) * p2.dx;
    final y = pow(1 - t, 2) * p0.dy +
        2 * (1 - t) * t * control.dy +
        pow(t, 2) * p2.dy;

    return Offset(x.toDouble(), y.toDouble());
  }

  double _calculateScale(double t) {
    return 1.0 - 0.7 * t; // from 1.0 to 0.3
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (_, __) {
        final offset = _calculateParabolicOffset(_curve.value);
        final scale = _calculateScale(_curve.value);

        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.7),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
