import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/home_page.dart';
import 'package:swipply/pages/profile.dart';
import 'package:swipply/pages/saved_jobs.dart';
import 'package:http/http.dart' as http;
import 'package:swipply/widgets/cv_chevker.dart';

class MainLayout extends StatefulWidget {
  MainLayout({super.key});

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

  String? sanitizeField(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '{}' || str == 'null') return null;
    return str;
  }

  String _jobTitle = 'Etudiant';
  final ValueNotifier<int> currentTabIndex = ValueNotifier(0);
  bool _hasLoadedOnce = false;
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
    // Listen for tab changes:
    currentTabIndex.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    currentTabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    // If user tapped into the Profile tab (index 2), refresh immediately:
    if (currentTabIndex.value == 2) {
      fetchEmployeeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: white,
        inactiveColor: black_gray,
        backgroundColor: black,
        onTap: (index) {
          currentTabIndex.value = index; // ✅ Update selected tab
        },
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
        ],
      ),
      tabBuilder: (context, index) {
        return ValueListenableBuilder(
          valueListenable: currentTabIndex,
          builder: (context, currentIndex, _) {
            switch (index) {
              case 0:
                return const HomePage();
              case 1:
                return const SavedJobs();
              case 2:
                return Profile(currentTabIndex: currentTabIndex);
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
      {required this.index, required this.currentTabIndex});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentTabIndex,
      builder: (_, currentIndex, __) {
        final bool isSelected = currentIndex == index;
        return Icon(
          icon,
          size: isSelected ? 28 : 24,
          color: isSelected ? white : black_gray,
        );
      },
    );
  }
}
