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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/cv.dart';
import 'package:swipply/pages/job_description.dart';
import 'package:swipply/pages/notification.dart';
import 'package:swipply/pages/subscriptions.dart';
import 'package:swipply/services/api_service.dart';
import 'package:swipply/widgets/category_container.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

ValueNotifier<bool> isSwiping = ValueNotifier(false);

class _HomePageState extends State<HomePage> {
  double _swipeProgress = 0.0;
  String? fullName, address, email, phone;
  String? resume;
  bool cvLoading = false;
  final GlobalKey bellKey = GlobalKey();

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
  Completer<GoogleMapController> _mapController = Completer();
  bool _isMapLoading = true;
  ValueNotifier<bool> isSwiping = ValueNotifier(false);
  final GlobalKey<_GradientSwapButtonState> cancelBtnKey = GlobalKey();
  final GlobalKey<_GradientSwapButtonState> rewindBtnKey = GlobalKey();
  final GlobalKey<_GradientSwapButtonState> likeBtnKey = GlobalKey();
  String? profileImageUrl;
  List<Map<String, dynamic>> jobs = [];
  bool isLoading = true;

  int _currentPage = 0;
  Map<int, bool> _expandedMaps = {};
  int _currentIndex = 0; // Track the current card index

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
    setState(() {
      if (_currentPage > 0) {
        _currentPage--;
        _isMapLoading = true;
      }
    });
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
      print("🟡 Swipe response: $data");
      return data['success'] == true;
    } else {
      print("❌ Swipe failed: ${response.statusCode} - ${response.body}");
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
    } catch (e) {
      print('❌ Decode error: $e');
    }

    return [];
  }

  String? jobTitle;
  String? sanitizeField(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '{}' || str == 'null') return null;
    return str;
  }

  bool get isCvComplete {
    return fullName != null &&
        address != null &&
        email != null &&
        phone != null &&
        resume != null &&
        education.isNotEmpty &&
        languages.isNotEmpty;
  }

  final int dailySwipeLimit = 100;

  Future<int> getLocalSwipeCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('swipe_date') ?? '';
    if (storedDate != today) {
      await prefs.setString('swipe_date', today);
      await prefs.setInt('swipe_count', 0);
      return 0;
    }
    return prefs.getInt('swipe_count') ?? 0;
  }

  Future<void> incrementLocalSwipeCount() async {
    final prefs = await SharedPreferences.getInstance();
    int current = await getLocalSwipeCount();
    await prefs.setInt('swipe_count', current + 1);
  }

  Future<bool> canSwipeLocally() async {
    int current = await getLocalSwipeCount();
    return current < dailySwipeLimit;
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            constraints: const BoxConstraints(minHeight: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    color: Color(0xFFFF4C4C), size: 40),
                const SizedBox(height: 20),
                const Text(
                  "Daily Limit Reached",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "You've reached your daily swipe limit.\nUpgrade your plan to unlock unlimited swipes.",
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
                        child: const Text(
                          "Upgrade Plan",
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
                          "Cancel",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
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
                  "Complete your CV",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "To apply for jobs or personalize your CV, please finish setting up your profile.",
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
                        child: const Text("Go to CV",
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
                        child: const Text("Cancel",
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Application sent successfully.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("❌ Error during auto-apply: $e");
    }
  }

  Future<void> _personalizeCv(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
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
          final personalizedData = json.decode(cvRes.body);

          setState(() {
            resume = personalizedData['personalized_resume'] ?? resume;
            jobTitle = personalizedData['job_title'] ?? jobTitle;
            fullName = personalizedData['full_name'] ?? fullName;

            education =
                _safeDecodeStringifiedSet(personalizedData['education']);
            experiences = List<String>.from(
                personalizedData['experience'] ?? experiences);

            softSkills = _safeDecodeList(personalizedData['soft_skills']);
            languages = _safeDecodeList(personalizedData['languages']);
            interests = _safeDecodeList(personalizedData['interests']);

            certificates = personalizedData['certificates'] ?? certificates;
            skillsAndProficiency = personalizedData['skills_and_proficiency'] ??
                skillsAndProficiency;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("CV personalized successfully.")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load personalized CV.")),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      color: Color(0xFFFF4C4C), size: 40),
                  const SizedBox(height: 20),
                  const Text(
                    "Upgrade to Unlock",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "You’ve reached your daily limit for personalized CVs.\nUpgrade your plan to continue personalizing.",
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
                          child: const Text("Upgrade Plan",
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
                          child: const Text("Cancel",
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      //
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
          print('Raw education field: ${empData['education']}');

          resume = empData['resume'];
          education = empData['education'] is List
              ? List<String>.from(empData['education'].map((e) => e.toString()))
              : _safeDecodeStringifiedSet(empData['education']);

          experiences = _safeDecodeStringifiedSet(empData['experience']);

          languages = _safeDecodeList(empData['languages']);
          interests = _safeDecodeList(empData['interests']);
          softSkills = _safeDecodeList(empData['soft_skills']);

          certificates = empData['certificates'] ?? [];
          skillsAndProficiency = empData['skills_and_proficiency'] ?? [];
        });
        print("Education Raw Data: ${empData['education']}");
        print("Fetched User Data: $userData");
        print("Fetched Employee Data: $empData");

        print("Parsed Education: $education");
      } catch (e) {
        print('❌ Error during profile parsing: $e');
      } finally {
        if (mounted) {
          setState(() {
            cvLoading = false;
          });
        }
      }
    } else {
      print("❌ Error fetching profile: ${userRes.body} | ${empRes.body}");
    }
  }

  void _fetchJobs() async {
    try {
      final fetchedJobs = await ApiService.fetchAllJobs();
      setState(() {
        jobs = fetchedJobs;
        isLoading = false;
      });

      // Initialize expanded maps
      for (int i = 0; i < fetchedJobs.length; i++) {
        _expandedMaps[i] = false;
      }
    } catch (e) {
      print("❌ Failed to fetch jobs: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _fetchUserProfile();
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
              icon: const Icon(
                CupertinoIcons.slider_horizontal_3,
                color: Colors.white,
                size: 26,
              ),
              onPressed: () {
                // Implement your filter functionality here
              },
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : jobs.isEmpty
                ? const Center(
                    child: Text("No jobs found.",
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
                                    final cvOK = await _checkCvComplete();
                                    if (!cvOK) {
                                      await showCustomCVDialog();
                                      return false; // block the swipe immediately
                                    }
                                    if (direction ==
                                        CardSwiperDirection.right) {
                                      final allowed = await canSwipeLocally();
                                      if (!allowed) {
                                        await showSwipeLimitReachedDialog(
                                            context);

                                        return false;
                                      }
                                      final jobId =
                                          jobs[previousIndex]['job_id'];
                                      await _autoRegisterAndApply(jobId);
                                      await incrementLocalSwipeCount();
                                    }

                                    // ✅ allow swipe and continue
                                    if (direction == CardSwiperDirection.left) {
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
                                    return true;
                                  },
                                  numberOfCardsDisplayed: 2,
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

  static Future<List<Map<String, dynamic>>> fetchAllJobs() async {
    final response = await http.get(Uri.parse('$BASE_URL_AUTH/api/get-jobs'));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Failed to fetch jobs');
    }
  }

  Widget _buildJobCard(int index) {
    bool isCurrentCard = index == _currentIndex;
    final String salary = jobs[index]["salary"] ?? "Not specified";
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      jobs[index]["company_logo_url"] ?? '',
                      height: 75,
                      width: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  jobs[index]["title"] ?? "No Title",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  jobs[index]["company_name"] ?? "Unknown",
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
                            .take(3)
                            .map<Widget>(
                                (chip) => CategoryChip(label: chip.toString()))
                            .toList()
                      else ...[
                        CategoryChip(
                            label: jobs[index]["employment_type"] ?? "Unknown"),
                        CategoryChip(
                            label: jobs[index]["contract_type"] ?? "Unknown"),
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
                    jobs[index]["description"] ?? "Unknown",
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

  Widget _buildInfoCard(
      {required IconData icon, required String title, required String value}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.44,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7F8FA),
            Color(0xFFECEFF1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                )
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.black87, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _showSecondAndThird(String text) {
    final parts = text.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 3) {
      return '${parts[1]}, ${parts[2]}';
    } else if (parts.length == 2) {
      return parts[1];
    } else {
      return parts.first;
    }
  }

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
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) {
                                        print(
                                            "❌ Error loading image: $profileImageUrl");
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
                            'Contact',
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
                                  phone ?? 'No phone',
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
                                  email ?? 'No email',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text(
                            'Education',
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
                                    'No education data',
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
                                    'No skills entered',
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
                              child: Container(
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
                              child: Container(
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
                            'Resume',
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
                                (resume ?? 'No resume added yet.'),
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
                            'Experience',
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
                                    'No experience added.',
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
          onPressed: () {
            _personalizeCv(jobs[index]['job_id']);
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
                _controller.swipe(CardSwiperDirection.left);
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

              if (!isCvComplete) {
                await showCustomCVDialog();

                return;
              }

              final allowed = await canSwipeLocally();
              if (!allowed) {
                showSwipeLimitReachedDialog(context);
                return;
              }

              await incrementLocalSwipeCount();

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
  const RingingBellButton({required this.bellKey, Key? key}) : super(key: key);
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
    } catch (e, stack) {
      print("❌ Ring bell error: $e\n$stack");
    }
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

final GlobalKey _notificationKey = GlobalKey();

class AnimatedFlyingCircle extends StatefulWidget {
  final Offset start;
  final Offset end;
  final VoidCallback onComplete;

  const AnimatedFlyingCircle({
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
