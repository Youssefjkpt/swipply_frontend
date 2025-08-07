import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/job_categories.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/home_page.dart';
import 'package:swipply/pages/job_description.dart';
import 'package:http/http.dart' as http;

class SavedJobs extends StatefulWidget {
  const SavedJobs({super.key});

  @override
  State<SavedJobs> createState() => _SavedJobsState();
}

class _SavedJobsState extends State<SavedJobs> {
  List<Map<String, dynamic>> _jobList = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _loadSavedJobs();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Refresh every 60 seconds
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadSavedJobs(),
    );
  }

  Future<void> _loadSavedJobs() async {
    setState(() => _isLoading = true);
    try {
      _jobList = await fetchSavedJobs();
    } catch (e) {
      print("❌ Error fetching saved jobs: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchSavedJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) {
      throw Exception("User ID not found in SharedPreferences");
    }

    final res = await http.get(
      Uri.parse('$BASE_URL_AUTH/api/saved-jobs?user_id=$userId'),
    );
    if (res.statusCode != 200) {
      print("❌ saved-jobs failed: ${res.statusCode}");
      print("Response body: ${res.body}");
      return [];
    }
    final List<dynamic> data = json.decode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }

  String _selectedCategory = 'Tout';
  @override
  Widget build(BuildContext context) {
    final visibleJobs = _selectedCategory == 'Tout'
        ? _jobList
        : _jobList
            .where(
              (j) =>
                  (j['job_category'] ?? '').toString().toLowerCase() ==
                  _selectedCategory.toLowerCase(),
            )
            .toList();

    return Scaffold(
      backgroundColor: black,
      body: RefreshIndicator(
        color: blue,
        onRefresh: _loadSavedJobs,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text.rich(
                TextSpan(
                  text:
                      'Vous avez enregistré ${_jobList.length} offre${_jobList.length != 1 ? 's' : ''} ',
                  style: const TextStyle(
                    color: white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    if (_jobList.isEmpty) // <- show only when 0
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Lottie.asset(
                          angry,
                          width: 50,
                          height: 50,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 25, right: 25),
              child: CategoryChipsBar(
                onCategorySelected: (cat) =>
                    setState(() => _selectedCategory = cat),
              ),
            ),
            const SizedBox(height: 20),

            // 🔥 THIS PART scrolls only the job cards:
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleJobs.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.1,
                            ),
                            Lottie.asset(notFound,
                                height:
                                    MediaQuery.of(context).size.height * 0.3,
                                width: MediaQuery.of(context).size.width),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: visibleJobs.length,
                          itemBuilder: (context, index) {
                            final job = visibleJobs[index];
                            final savedAtRaw = job['saved_at'] as String? ??
                                job['scraped_at']
                                    as String? // fallback if you still have scraped_at
                                ??
                                '';
                            final savedAt =
                                DateTime.tryParse(savedAtRaw) ?? DateTime.now();

                            final now = DateTime.now();
                            final diff = now.difference(savedAt);
                            final timeAgo = diff.inHours < 24
                                ? 'il y a ${diff.inHours} h'
                                : 'il y a ${diff.inDays} jour ${diff.inDays > 1 ? 's' : ''}';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: JobCard(
                                title: job['title'] ?? '',
                                company: job['company'] ?? '',
                                salary: timeAgo,
                                location: job['location'] ?? '',
                                status: 'en attente',
                                jobType: job['contract_type'] ?? '',
                                imagePath: job['company_logo_url']!,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => JobInformations(
                                          job: job), // ✅ Pass job
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            )),
          ],
        ),
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final String title;
  final String company;
  final String salary;
  final String location;
  final String status;
  final String jobType;
  final String imagePath;
  final VoidCallback? onTap;

  const JobCard({
    super.key,
    required this.title,
    required this.company,
    required this.salary,
    required this.location,
    required this.status,
    required this.jobType,
    required this.imagePath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131720),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 25),
                SizedBox(
                    height: 50,
                    width: 50,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CompanyLogo(imagePath),
                    )),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: white_gray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        salary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: white_gray,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 25),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 25),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: _getTintedWhite(status),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 7,
                    ),
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox(width: 1)),
                Text(
                  jobType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 25),
              ],
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'postulé':
        return Colors.green;
      case 'fermé':
        return Colors.red;
      case 'en attente':
        return Colors.blue;
      default:
        return white_gray;
    }
  }

  Color _getTintedWhite(String status) {
    switch (status.toLowerCase()) {
      case 'postulé':
        return const Color.fromARGB(255, 215, 255, 217).withOpacity(1);
      case 'fermé':
        return Color.fromARGB(255, 255, 221, 219).withOpacity(1);
      case 'en attente':
        return const Color.fromARGB(255, 211, 235, 255).withOpacity(1);
      default:
        return white.withOpacity(0.08);
    }
  }
}

class CategoryChipsBar extends StatefulWidget {
  const CategoryChipsBar({
    super.key,
    required this.onCategorySelected,
  });

  final ValueChanged<String> onCategorySelected;

  @override
  State<CategoryChipsBar> createState() => _CategoryChipsBarState();
}

class _CategoryChipsBarState extends State<CategoryChipsBar> {
  final List<String> categories = kJobCategories;

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(categories.length, (index) {
          final bool isSelected = index == selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => selectedIndex = index);
                widget.onCategorySelected(categories[index]);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? blue : black,
                  borderRadius: BorderRadius.circular(100),
                  border: isSelected
                      ? null
                      : Border.all(color: white_gray, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Text(
                  categories[index],
                  style: TextStyle(
                    color: isSelected ? black : white_gray,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
