import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/home_page.dart';
import 'package:swipply/pages/profile.dart';
import 'package:swipply/pages/saved_jobs.dart';
import 'package:http/http.dart' as http;
import 'package:swipply/pages/settings.dart';
import 'package:swipply/widgets/cv_chevker.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String? resume;
  List<String> experience = [];
  List<String> education = [];
  List<String> languages = [];
  List<String> interests = [];
  List<String> softSkills = [];
  List<dynamic> certificates = [];
  List<dynamic> skillsAndProficiency = [];
  Map<String, dynamic>? weeklyAvailability;
  String? availability;
  String? fullName;
  String? profilePicturePath;

  final CupertinoTabController _tabController =
      CupertinoTabController(initialIndex: 0);

  String? sanitizeField(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '{}' || str == 'null') return null;
    return str;
  }

  String _jobTitle = 'Etudiant';
  final ValueNotifier<int> currentTabIndex = ValueNotifier(0);
  bool _hasLoadedOnce = false;
  final ValueNotifier<ProfileData?> _profileNotifier =
      ValueNotifier<ProfileData?>(null);
  Future<void> fetchEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      print("❌ No user ID found");
      return;
    }

    try {
      final employeeResponse = await http.get(
        Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'),
      );

      final userResponse = await http.get(
        Uri.parse('$BASE_URL_AUTH/users/$userId'),
      );

      if (employeeResponse.statusCode == 200 &&
          userResponse.statusCode == 200) {
        final employeeData = jsonDecode(employeeResponse.body);
        final userData = jsonDecode(userResponse.body);

        setState(() {
          _jobTitle = sanitizeField(userData['job_title']) ?? '';
          profilePicturePath = sanitizeField(userData['profile_photo_url']);

          fullName = sanitizeField(userData['full_name']);
          resume = sanitizeField(employeeData['resume']);

          experience = (employeeData['experience'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          education = (employeeData['education'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          languages = (employeeData['languages'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          interests = (employeeData['interests'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          softSkills = (employeeData['soft_skills'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          certificates = employeeData['certificates'] ?? [];
          skillsAndProficiency = employeeData['skills_and_proficiency'] ?? [];

          weeklyAvailability = employeeData['weekly_availability'];
          availability = employeeData['availability'];
        });

        await CVChecker.updateCVStatus(employeeData);
        final status = await CVChecker.isCVIncomplete();
        final missing = await CVChecker.getMissingFields();

        setState(() {
          isCVIncomplete = status;
          missingFields = missing;
        });

        print("✅ Employee and user data loaded successfully");
      } else {
        print(
            "❌ Failed to fetch data: ${employeeResponse.body} | ${userResponse.body}");
      }
    } catch (e) {
      print("❌ Error fetching profile data: $e");
    }
  }

  bool isCVIncomplete = false;
  List<String> missingFields = [];
  Future<void> _refreshProfile() async {
    setState(() {
      _hasLoadedOnce = false;
    });
    await fetchEmployeeData();
  }

  @override
  void initState() {
    super.initState();

    // 1️⃣ notifier → controller _and_ refresh Profile when value == 2
    currentTabIndex.addListener(() {
      final newIdx = currentTabIndex.value;
      if (_tabController.index != newIdx) {
        _tabController.index = newIdx;
      }
      if (newIdx == 2) fetchEmployeeData();
    });

    // 2️⃣ controller → notifier (keeps your pages in sync when user taps)
    _tabController.addListener(() {
      final idx = _tabController.index;
      if (currentTabIndex.value != idx) {
        currentTabIndex.value = idx;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    currentTabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        activeColor: white,
        inactiveColor: const Color.fromARGB(255, 95, 102, 120),
        backgroundColor: black,
        onTap: (i) => _tabController.index = i,
        items: [
          BottomNavigationBarItem(
            icon: NavIcon(CupertinoIcons.house_fill,
                index: 0, currentTabIndex: currentTabIndex),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: NavIcon(CupertinoIcons.bookmark_fill,
                index: 1, currentTabIndex: currentTabIndex),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: NavIcon(CupertinoIcons.person,
                index: 2, currentTabIndex: currentTabIndex),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            // NEW
            icon: NavIcon(CupertinoIcons.settings, // NEW
                index: 3,
                currentTabIndex: currentTabIndex), // NEW
            label: 'Settings', // NEW
          ),
        ],
      ),
      tabBuilder: (context, _) {
        return ValueListenableBuilder<int>(
          valueListenable: currentTabIndex,
          builder: (_, currentIndex, __) {
            switch (currentIndex) {
              case 0:
                return const HomePage();
              case 1:
                return const SavedJobs();
              case 2:
                return Profile(
                  currentTabIndex: currentTabIndex,
                  dataListenable: _profileNotifier,
                  onRefreshRequested: fetchEmployeeData,
                );
              case 3:
                return MainSettings(currentTabIndex: currentTabIndex);
              default:
                return const Center(child: Text('Unknown tab'));
            }
          },
        );
      },
    );
  }
}

class NavIcon extends StatelessWidget {
  final IconData icon;
  final int index;
  final ValueNotifier<int> currentTabIndex; // ✅ Pass the same notifier

  const NavIcon(this.icon,
      {super.key, required this.index, required this.currentTabIndex});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentTabIndex,
      builder: (_, currentIndex, __) {
        final bool isSelected = currentIndex == index;
        return Icon(
          icon,
          size: isSelected ? 28 : 24,
          color: isSelected ? white : const Color.fromARGB(255, 95, 102, 120),
        );
      },
    );
  }
}

// ───── profile_data.dart-ish (put it in this file for now) ─────────
class ProfileData {
  const ProfileData({
    required this.fullName,
    required this.jobTitle,
    this.photoUrl,
    required this.cvIncomplete,
    required this.missingFields,
  });

  final String fullName;
  final String jobTitle;
  final String? photoUrl;
  final bool cvIncomplete;
  final List<String> missingFields;
}
