import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/job_description.dart';
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
          final rawPath = userData['profile_picture'];
          if (rawPath != null && rawPath.toString().isNotEmpty) {
            profileImageUrl = '$BASE_URL_AUTH$rawPath';
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
          education = _safeDecodeStringifiedSet(empData['education']);
          experiences = _safeDecodeStringifiedSet(empData['experience']);

          languages = _safeDecodeList(empData['languages']);
          interests = _safeDecodeList(empData['interests']);
          softSkills = _safeDecodeList(empData['soft_skills']);

          certificates = empData['certificates'] ?? [];
          skillsAndProficiency = empData['skills_and_proficiency'] ?? [];
        });
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
            Container(
              margin: const EdgeInsets.only(right: 15),
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: white_gray,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.notifications,
                color: white,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 15),
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: white_gray,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.sort_rounded,
                color: white,
              ),
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
                                    //_triggerSwipeEffect(direction);
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

  Widget _buildJobCard(int index) {
    bool isCurrentCard = index == _currentIndex;

    return Stack(
      children: [
        Container(
          width: double.infinity,
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
                        colors: [
                          white, Color.fromARGB(255, 201, 201, 201),
                          white_gray,

                          Color.fromARGB(255, 23, 23,
                              23), // Black gradient only for the current card
                        ],
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
                    child: Image.network(
                      jobs[index]["company_background_url"] ?? '',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(welcome_img, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
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
                              height: 65,
                              width: 65,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported,
                                  size: 30),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              const SizedBox(height: 5),
                              Text(
                                jobs[index]["company_name"] ?? "Unknown",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: black_gray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (index < jobs.length) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JobInformations(job: jobs[index]),
                                ),
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                                color: white,
                                border: Border.all(color: black, width: 0.5),
                                borderRadius: BorderRadius.circular(100)),
                            child: const Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      jobs[index]["description"] ?? "Unknown",
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: black_gray,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),

              // Apply Gradient ONLY to the Current Card

              // Text overlay
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                            child: SizedBox(
                          width: 1,
                        )),
                        Container(
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _showSecondAndThird(
                                    jobs[index]["location"] ?? "Unknown",
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.black87,
                                size: 18,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 5,
                      runSpacing: 8,
                      children: [
                        if (jobs[index]["category_chip"] != null &&
                            jobs[index]["category_chip"] is List &&
                            jobs[index]["category_chip"].isNotEmpty)
                          ...jobs[index]["category_chip"]
                              .take(5)
                              .map<Widget>((chip) =>
                                  CategoryChip(label: chip.toString()))
                              .toList()
                        else ...[
                          CategoryChip(
                              label:
                                  jobs[index]["employment_type"] ?? "Unknown"),
                          CategoryChip(
                              label: jobs[index]["contract_type"] ?? "Unknown"),
                        ],
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildPageIndicator()
      ],
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
                              child: profileImageUrl != null
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
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 34),
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
                            decoration: BoxDecoration(color: white),
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
                          SizedBox(
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
                            decoration: BoxDecoration(color: white),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          education.isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: education.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '• ',
                                            style: TextStyle(
                                                color: white, fontSize: 12),
                                          ),
                                          Expanded(
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                  color: white, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                )
                              : const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'No education data',
                                    style:
                                        TextStyle(color: white, fontSize: 12),
                                  ),
                                ),
                          SizedBox(
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
                            decoration: BoxDecoration(color: white),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          softSkills.isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                                  color: white, fontSize: 12)),
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
                    SizedBox(
                      width: 10,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullName != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 35, bottom: 4, left: 20),
                            child: Expanded(
                              child: Text(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                fullName!.toUpperCase(),
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
                            padding: const EdgeInsets.only(bottom: 5, left: 20),
                            child: Expanded(
                              child: Text(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                jobTitle!.toUpperCase(),
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
                            color: Color.fromARGB(255, 37, 57, 138),
                          ),
                        ),
                        SizedBox(
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
                          decoration: BoxDecoration(
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
                          color: Color.fromARGB(255, 37, 57, 138),
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
                    )
                  ],
                ),
        ),
        _buildPageIndicator(),
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
            onPressed: () {
              likeBtnKey.currentState?.triggerSwapExternally();
              Future.delayed(const Duration(milliseconds: 150), () {
                _controller.swipe(CardSwiperDirection.right);
              });
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
