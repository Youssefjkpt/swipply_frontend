import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/job_applications_progress.dart';
import 'package:swipply/pages/premium_purchase_plan.dart';
import 'package:swipply/widgets/ai_auto_apply_notification_page.dart';

class ApplicationsInProgressPage extends StatefulWidget {
  @override
  State<ApplicationsInProgressPage> createState() =>
      _ApplicationsInProgressPageState();
}

class _ApplicationsInProgressPageState extends State<ApplicationsInProgressPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _applications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final token = prefs.getString('token');
      if (userId == null || token == null) {
        setState(() => isLoading = false);
        return;
      }

      final resp = await http.get(
        Uri.parse(
            '$BASE_URL_AUTH/api/applications-in-progress?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final list = (data['applications'] as List?) ?? [];
        setState(() {
          _applications = list.map((raw) {
            final app = raw as Map<String, dynamic>;
            return {
              'JobListings': app['JobListings'],
              'progress_status': (app['progress_status'] as int?) ?? 0,
              // null-safe cast:
              'application_status':
                  (app['application_status']?.toString() ?? ''),
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) filter only initializing/pending jobs
    final pending = _applications.where((app) {
      final status = app['application_status'].toString().toLowerCase();
      return status.contains('initial') || status.contains('pending');
    }).toList();
    final progresses = _applications
        .map((app) => (app['progress_status'] as int).clamp(0, 100))
        .toList();
    if (isLoading || pending.isEmpty) {
      // show loader or empty
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Notifications',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: const BackButton(color: Colors.white),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent))
            : const Center(
                child: Text(
                  "Aucune notification pour le moment.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
      );
    }

    // 2) pick the one with highest progress
    pending.sort((a, b) =>
        (b['progress_status'] as int).compareTo(a['progress_status'] as int));
    final active = pending.first;

    // 3) compute bar params
    final totalStages = pending.length;
    final currentStage = pending.indexOf(active);
    final fraction = (active['progress_status'] as int).clamp(0, 100) / 100.0;
    final progressFraction =
        (active['progress_status'] as int).clamp(0, 100) / 100;

    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Notifications',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
          ),
          centerTitle: true,
          leading: const BackButton(color: Colors.white),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )
            : _applications.isEmpty
                ? const Center(
                    child: Text(
                      "Aucune notification pour le moment.",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : Column(children: [
                    // Top container for summary or other content
                    AIApplicationServiceCard(
                      onActivate: () {
                        // TODO: navigate to your AI-activation flow
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    SwipplyPremiumDetailsPage()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Candidature en cours',
                            style: TextStyle(
                                color: white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const Expanded(
                              child: SizedBox(
                            width: 1,
                          )),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        JobApplicationsProgress())),
                            child: const Row(
                              children: [
                                Text(
                                  'Voir tout',
                                  style: TextStyle(
                                      color: white_gray,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: white_gray,
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ), //////////////////////
                    Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: blue_gray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Builder(
                          builder: (context) {
                            final count = _applications.length.clamp(0, 3);
                            final containerHeight =
                                40.0 + count * 96.0 + (count - 1) * 8.0;
                            return SizedBox(
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Ligne d’attente + statut
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Lottie animé
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                20, 16, 16, 8),
                                            child: Container(
                                              height: 75,
                                              width: 75,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF384158),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.4),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Lottie.asset(
                                                  applying,
                                                  fit: BoxFit.contain,
                                                  repeat: true,
                                                  animate: true,
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 4),

                                          // Texte patient + ratio
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              const Text(
                                                'Patientez un instant…',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.3,
                                                    child: const Text(
                                                      'Vos candidatures sont en cours d\'envoi...',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w300,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 3,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 20),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            const LinearGradient(
                                                          colors: [
                                                            Color(0xFF00FFAA),
                                                            Color(0xFF00C28C)
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(100),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(
                                                                    0xFF00FFAA)
                                                                .withOpacity(
                                                                    0.3),
                                                            blurRadius: 10,
                                                            offset:
                                                                const Offset(
                                                                    0, 4),
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                                15, 8, 15, 8),
                                                        child: Text(
                                                          'En attente',
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 20),
                                      // …later in your Column:
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 10, right: 10),
                                        child: AnimatedSegmentedProgressBar(
                                          progresses: progresses,
                                          height: 6.0, // match your design
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ))
                  ]));
  } // Place this inside your build, replacing the static progress bar:
}

class AnimatedSegmentedProgressBar extends StatefulWidget {
  final List<int> progresses;
  final double height;
  final double gap;

  const AnimatedSegmentedProgressBar({
    Key? key,
    required this.progresses,
    this.height = 8.0,
    this.gap = 4.0,
  }) : super(key: key);

  @override
  _AnimatedSegmentedProgressBarState createState() =>
      _AnimatedSegmentedProgressBarState();
}

class _AnimatedSegmentedProgressBarState
    extends State<AnimatedSegmentedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillCtrl;

  @override
  void initState() {
    super.initState();
    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalStages = widget.progresses.length;
        final maxTotal = totalStages * 100;
        final rawSum = widget.progresses.fold<int>(0, (sum, p) => sum + p);
        final sumProgress = rawSum.clamp(0, maxTotal);

        final completedStages = (sumProgress ~/ 100).clamp(0, totalStages);
        final currentFraction = (sumProgress % 100) / 100.0;

        // Total gap space
        final totalGapWidth = widget.gap * (totalStages - 1);
        final usableWidth = constraints.maxWidth - totalGapWidth;
        final segmentWidth = usableWidth / totalStages;

        return Row(
          children: List.generate(totalStages * 2 - 1, (index) {
            if (index.isOdd) {
              // Gap between segments
              return SizedBox(width: widget.gap);
            }
            final i = index ~/ 2;
            final isCompleted = i < completedStages;
            final isCurrent = i == completedStages;

            final double staticFillWidth = isCompleted
                ? segmentWidth
                : isCurrent
                    ? segmentWidth * currentFraction
                    : 0.0;

            return SizedBox(
              width: segmentWidth,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Background track
                  Container(
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(widget.height),
                    ),
                  ),
                  // Static white fill showing limit
                  if (isCompleted || isCurrent)
                    Container(
                      height: widget.height,
                      width: staticFillWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height),
                        gradient: const LinearGradient(
                          colors: [white, Colors.white70],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  // Animated green fill behind white
                  AnimatedBuilder(
                    animation: _fillCtrl,
                    builder: (_, __) {
                      final greenWidth = isCompleted
                          ? segmentWidth
                          : isCurrent
                              ? staticFillWidth * _fillCtrl.value
                              : 0.0;
                      return Container(
                        height: widget.height,
                        width: greenWidth,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C28C), Color(0xFF00FFAA)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(widget.height),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

Widget _buildJobCard(Map<String, dynamic> app) {
  final job = app['JobListings'];
  final title = job?['title'] ?? 'Titre de l\'emploi';
  final company = job?['company'] ?? '';
  final logo = job?['company_logo_url'] ?? '';
  final raw = (app['progress_status'] ?? 0).toDouble().clamp(0, 100);
  final progress = raw / 100;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: blue_gray,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: logo.isNotEmpty
              ? Image.network(logo, width: 60, height: 60, fit: BoxFit.cover)
              : Container(width: 60, height: 60, color: Colors.grey[800]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                company,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade700,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.greenAccent : Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class FullApplicationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> applications;
  const FullApplicationsPage(this.applications, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Toutes les candidatures',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: applications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, idx) => _buildJobCard(applications[idx]),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> app) {
    final job = app['JobListings'];
    final jobTitle = job?['title'] ?? 'Titre de l\'emploi';
    final companyName = job?['company'] ?? 'Nexora';
    final companyLogo = job?['company_logo_url'] ?? '';
    final location = job?['location'] ?? 'Lieu inconnu';
    final rawProgress = (app['progress_status'] ?? 0).toDouble().clamp(0, 100);
    final progress = rawProgress / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blue_gray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: companyLogo.isNotEmpty
                ? Image.network(
                    companyLogo,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Container(width: 60, height: 60, color: Colors.grey[800]),
          ),
          const SizedBox(width: 12), // Adjusted to be smaller
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  jobTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Prevents overflow
                ),
                const SizedBox(
                    height: 4), // Reduced gap between title and company
                Text(
                  companyName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Prevents overflow
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Prevents overflow
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(100),
                  backgroundColor: Colors.grey.shade700,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.greenAccent : Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% complet',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // You can reuse the same _buildJobCard or move it here as well.
}
