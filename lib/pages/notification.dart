import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/job_applications_progress.dart';
import 'package:swipply/pages/premium_purchase_plan.dart';
import 'package:swipply/pages/saved_jobs.dart';
import 'package:swipply/widgets/ai_auto_apply_notification_page.dart';
import 'package:swipply/widgets/backup_email.dart';

class ApplicationsInProgressPage extends StatefulWidget {
  @override
  State<ApplicationsInProgressPage> createState() =>
      _ApplicationsInProgressPageState();
}

class _ApplicationsInProgressPageState extends State<ApplicationsInProgressPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _applications = [];
  bool isLoading = true;
  bool hasError = false;
  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final token = prefs.getString('token');
      debugPrint('▶︎ SP: user_id=$userId, token=$token');

      if (userId == null || token == null) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
        return;
      }

      final uri = Uri.parse(
          '$BASE_URL_AUTH/api/applications-in-progress?user_id=$userId');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('▶︎ GET ${uri.toString()} → ${resp.statusCode}');
      debugPrint('▶︎ body: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;

        // 1) On extrait bien la liste sous la clé "applications"
        final rawList = (data['applications'] as List<dynamic>?) ?? [];
        debugPrint('▶︎ rawList.length = ${rawList.length}');

        // 2) On convertit chaque élément en Map<String, dynamic>
        final allApps = rawList.map((raw) {
          final app = raw as Map<String, dynamic>;
          debugPrint('▶︎ raw app obj: $app');

          return {
            'application_id': app['application_id'] as String? ?? '',
            // ATTENTION : si votre backend utilise "JobListings" (camelCase), on le récupère ici
            'JobListings': (app['JobListings'] as Map<String, dynamic>?) ?? {},
            'progress_status':
                (app['progress_status'] as int?)?.clamp(0, 100) ?? 0,
            'application_status': (app['application_status'] as String?) ?? '',
            'error_message': (app['error_message'] as String?) ?? '',
          };
        }).toList();

        // 3) On conserve uniquement ceux dont "progress_status" < 100
        final pending =
            allApps.where((a) => (a['progress_status'] as int) < 100).toList();

        setState(() {
          _applications = pending;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
          _applications = [];
        });
      }
    } catch (e) {
      debugPrint('❌ Exception in _fetchApplications: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        _applications = [];
      });
    }
  }

  Future<bool> _hideApplicationOnServer(String applicationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return false;

    final uri = Uri.parse(
      '$BASE_URL_AUTH/api/applications/$applicationId/hide',
    );
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    debugPrint(
      '→ [HideApplication] POST ${uri.toString()} → ${resp.statusCode}, body: ${resp.body}',
    );
    return resp.statusCode == 200;
  }

  @override
  Widget build(BuildContext context) {
    // 1) filter only initializing/pending jobs

    final pending = _applications;

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

    // 3) compute bar params
    if (isLoading) {
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
        body: const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }
    if (pending.isEmpty) {
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
        body: const Center(
          child: Text(
            "Aucune notification pour le moment.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    return Scaffold(
        backgroundColor: const Color(0xFF0B0B0E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Notifications',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
          ),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.all(4),
            child: _GlassIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop()),
          ),
        ),
        body: Stack(
          children: [
            const _AuroraBackground(),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(children: [
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
                          return SizedBox(
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              padding: const EdgeInsets.all(8),
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
                                                  width: MediaQuery.of(context)
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
                                                          BorderRadius.circular(
                                                              100),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(
                                                                  0xFF00FFAA)
                                                              .withOpacity(0.3),
                                                          blurRadius: 10,
                                                          offset: const Offset(
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
                      )),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Text(
                        'Conseils du jour',
                        style: TextStyle(
                            color: white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      Expanded(
                          child: SizedBox(
                        width: 1,
                      ))
                    ],
                  ),
                  WarningEmailBackupCard(warningLottieAsset: warning),

                  OutOfLikesSaveCard(
                      onSavePressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SavedJobs()))),
                  DidYouKnowPersonalizeCard()
                ]),
              ),
            ),
          ],
        ));
  } // Place this inside your build, replacing the static progress bar:
}

class DidYouKnowPersonalizeCard extends StatelessWidget {
  const DidYouKnowPersonalizeCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blue_gray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: white_gray.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            size: 28,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Saviez‑vous ?',
                  style: TextStyle(
                    color: white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Vous pouvez personnaliser votre CV pour n’importe quel poste souhaité. Notre IA s’occupe de tout.',
                  style: TextStyle(
                    color: white_gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggestion card when out of likes: invite user to save jobs for later.
class OutOfLikesSaveCard extends StatelessWidget {
  final VoidCallback onSavePressed;

  const OutOfLikesSaveCard({
    Key? key,
    required this.onSavePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blue_gray, // use app's blue-gray background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: white_gray.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 32,
            color: Color(0xFF00FFAA), // neutral icon color
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Astuce',
                  style: TextStyle(
                    color: white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Plus de likes ? Enregistrez des offres pour y revenir et postuler plus tard.',
                  style: TextStyle(
                      color: white_gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w300),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
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

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();
  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        return CustomPaint(
          painter: _AuroraPainter(c.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFF09090C), Color(0xFF0E0E13)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)
          .createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    void blob(Offset o, double r, List<Color> colors) {
      final rect = Rect.fromCircle(center: o, radius: r);
      final paint = Paint()
        ..shader = RadialGradient(colors: colors).createShader(rect);
      canvas.drawCircle(o, r, paint);
    }

    final w = size.width;
    final h = size.height;
    blob(Offset(w * 0.15 + 20 * t, h * 0.2), 180,
        [const Color(0xFF00E6C3).withOpacity(0.20), Colors.transparent]);
    blob(Offset(w * 0.9 - 30 * t, h * 0.15), 160,
        [const Color(0xFF7CF9D2).withOpacity(0.18), Colors.transparent]);
    blob(Offset(w * 0.7, h * 0.95 - 25 * t), 220,
        [const Color(0xFFB388FF).withOpacity(0.18), Colors.transparent]);
    blob(Offset(w * 0.05, h * 0.8), 180,
        [const Color(0xFF6EC6FF).withOpacity(0.16), Colors.transparent]);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
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

class GodBackground extends StatefulWidget {
  final ValueListenable<double> scrollY;
  const GodBackground({required this.scrollY});
  @override
  State<GodBackground> createState() => _GodBackgroundState();
}

class _GodBackgroundState extends State<GodBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([c, widget.scrollY]),
      builder: (_, __) => CustomPaint(
          painter: _GodPainter(c.value, widget.scrollY.value),
          size: Size.infinite),
    );
  }
}

class _GodPainter extends CustomPainter {
  final double t;
  final double scroll;
  _GodPainter(this.t, this.scroll);
  @override
  void paint(Canvas canvas, Size size) {
    final parallax = (scroll * 0.02).clamp(-40.0, 80.0);
    final bg = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF07080B), Color(0xFF0B0C12)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    void glowBlob(Offset o, double r, List<Color> colors, double sigma) {
      final rect = Rect.fromCircle(center: o, radius: r);
      final paint = Paint()
        ..shader = RadialGradient(colors: colors).createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      canvas.drawCircle(o, r, paint);
    }

    final w = size.width, h = size.height;
    glowBlob(Offset(w * 0.18 + 30 * t, h * 0.22 + parallax), 160,
        [const Color(0xFF00FFE1).withOpacity(0.18), Colors.transparent], 24);
    glowBlob(Offset(w * 0.86 - 25 * t, h * 0.18 + parallax * 0.6), 150,
        [const Color(0xFF8CFFEB).withOpacity(0.14), Colors.transparent], 22);
    glowBlob(Offset(w * 0.65, h * 0.98 - 18 * t + parallax * 0.2), 220,
        [const Color(0xFFC6A7FF).withOpacity(0.12), Colors.transparent], 26);
    glowBlob(Offset(w * 0.06, h * 0.82 + parallax * 0.8), 180,
        [const Color(0xFF6EC6FF).withOpacity(0.10), Colors.transparent], 20);
    final paintWave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = const LinearGradient(
              colors: [Color(0xFF00FFE1), Color(0xFF7CF9D2)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight)
          .createShader(Rect.fromLTWH(0, 0, w, h))
      ..color = Colors.white.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    Path wave(double offsetY, double amp, double freq) {
      final p = Path()..moveTo(0, offsetY + parallax * 0.15);
      for (double x = 0; x <= w; x += 6) {
        final y = offsetY +
            parallax * 0.15 +
            amp * math.sin((x / w * freq * 2 * math.pi) + (t * 2 * math.pi));
        p.lineTo(x, y);
      }
      return p;
    }

    canvas.drawPath(wave(h * 0.28, 12, 2.2), paintWave);
    canvas.drawPath(wave(h * 0.62, 16, 1.6),
        paintWave..color = paintWave.color.withOpacity(0.14));
    for (int i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final start = Offset(-40, h * 0.2 + i * 60.0 + parallax * 0.3);
      final end = Offset(w + 40, h * 0.05 + i * 120.0 + parallax * 0.1);
      final pos = Offset.lerp(start, end, Curves.easeInOut.transform(p))!;
      final tailPaint = Paint()
        ..shader = LinearGradient(colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.2)
        ]).createShader(Rect.fromCircle(center: pos, radius: 60))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos.translate(-20, 12), 36, tailPaint);
      canvas.drawCircle(
          pos, 2.5, Paint()..color = Colors.white.withOpacity(0.9));
    }
    final stars = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (int i = 0; i < 70; i++) {
      final dx = (i * 73 % w).toDouble();
      final dy = (i * 131 % h).toDouble() + parallax * 0.2;
      final pulse = 1 + 0.6 * math.sin(t * 2 * math.pi + i * 0.3);
      canvas.drawCircle(Offset(dx, dy), 0.6 * pulse, stars);
    }
  }

  @override
  bool shouldRepaint(covariant _GodPainter old) =>
      old.t != t || old.scroll != scroll;
}
