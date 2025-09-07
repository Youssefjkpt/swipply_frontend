import 'dart:async';
import 'dart:convert';
import 'dart:ui';
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
import 'package:swipply/pages/home_page.dart';
import 'package:swipply/widgets/company_logo.dart';

class JobApplicationsProgress extends StatefulWidget {
  @override
  State<JobApplicationsProgress> createState() =>
      _JobApplicationsProgressState();
}

enum ApplicationState { queued, inProgress, success }

enum _Filter { all, queued, inProgress, success }

class _JobApplicationsProgressState extends State<JobApplicationsProgress> {
  List<Map<String, dynamic>> _applications = [];
  bool isLoading = true;
  final Set<String> _celebrated = {};
  final ValueNotifier<double> _scrollY = ValueNotifier(0);
  Timer? _poller;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(
        const Duration(seconds: 15), (_) => _fetchApplications());
    _fetchApplications();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _scrollY.dispose();
    super.dispose();
  }

// ---- DEBUG HELPERS ----------------------------------------------------------
  void dbg(Object? msg) {
    if (kDebugMode) debugPrint('[apps] $msg');
  }

  String _pickDescription(Map<String, dynamic> j) {
    final d = (j['description'] ?? '').toString().trim();
    final sd = (j['short_description'] ?? '').toString().trim();

    if (kDebugMode) {
      dbg('card.pickDescription keys=${j.keys.toList()}');
      dbg('card.pickDescription -> description=${prev(d)} | short_description=${prev(sd)}');
    }

    if (d.isNotEmpty) return d;
    return sd;
  }

  /// short preview for long strings in logs
  String prev(String? s, {int n = 120}) {
    if (s == null) return 'null';
    final t = s.replaceAll('\n', ' ');
    return (t.length <= n) ? t : '${t.substring(0, n)}…';
  }
// ----------------------------------------------------------------------------

  Future<void> _hideApplicationOnServer(String applicationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    final uri =
        Uri.parse('$BASE_URL_AUTH/api/applications/$applicationId/hide');
    await http.post(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
  }

  Future<void> _fetchApplications() async {
    if (!mounted) return;
    setState(() => isLoading = _applications.isEmpty);

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');

    if (userId == null || token == null) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }

    final url = '$BASE_URL_AUTH/api/applications-in-progress?user_id=$userId';
    dbg('GET $url');

    http.Response res;
    try {
      res = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      dbg('HTTP error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }

    dbg('status=${res.statusCode} len=${res.body.length}');
    if (kDebugMode && res.body.isNotEmpty) {
      // log only the first 1.5k chars to avoid spam
      dbg('body: ${prev(res.body, n: 1500)}');
    }

    if (res.statusCode != 200) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final rawApps = (body['applications'] as List<dynamic>?) ?? [];
    dbg('applications count=${rawApps.length}');

    final nextApps = <Map<String, dynamic>>[];

    // helper that we’ll log with
    String? pickDesc(Map<String, dynamic> m) {
      for (final k in const [
        'description',
        'short_description',
        'job_description'
      ]) {
        final v = m[k];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    for (int i = 0; i < rawApps.length; i++) {
      final raw = rawApps[i] as Map;
      final appId = raw['application_id']?.toString() ?? '?';
      final appMap = Map<String, dynamic>.from(raw);
      final jobSrc =
          Map<String, dynamic>.from((appMap['JobListings'] ?? {}) as Map);

      // log what keys we actually have
      if (i < 5) {
        // limit noise
        dbg('[$i] id=$appId '
            'job_keys=${jobSrc.keys.toList()} '
            'top_keys=${appMap.keys.take(20).toList()}');
        dbg('[$i]     top.description=${prev(appMap['description']?.toString())}');
        dbg('[$i]     top.short_description=${prev(appMap['short_description']?.toString())}');
        dbg('[$i]     job.description=${prev(jobSrc['description']?.toString())}');
        dbg('[$i]     job.short_description=${prev(jobSrc['short_description']?.toString())}');
      }

      final topDesc = pickDesc(appMap);
      final jobDesc = pickDesc(jobSrc);
      final chosen = jobDesc ?? topDesc;

      if (i < 5) {
        dbg('[$i] chosen_desc=${prev(chosen)} (jobDesc? ${jobDesc != null}, topDesc? ${topDesc != null})');
      }

      if (chosen != null) jobSrc['description'] = chosen;

      nextApps.add({
        'application_id': appId,
        'JobListings': jobSrc,
        'progress': (appMap['progress_status'] as num?)?.toDouble() ?? 0.0,
      });
    }

    if (!mounted) return;
    setState(() {
      _applications = nextApps;
      isLoading = false;
    });

    dbg('state set: apps=${_applications.length}');
  }

  ApplicationState _deriveState(Map<String, dynamic> app) {
    final p = (app['progress'] as double?)?.clamp(0.0, 100.0) ?? 0.0;
    if (p >= 100.0) return ApplicationState.success;
    if (p <= 0.0) return ApplicationState.queued;
    return ApplicationState.inProgress;
  }

  ({int sent, int success, int pending}) _computeStats() {
    int sent = _applications.length;
    int success = 0;
    int pending = 0;
    for (final app in _applications) {
      final s = _deriveState(app);
      if (s == ApplicationState.success) success++;
      if (s == ApplicationState.queued || s == ApplicationState.inProgress)
        pending++;
    }
    return (sent: sent, success: success, pending: pending);
  }

  List<Map<String, dynamic>> get _visibleApps {
    if (_filter == _Filter.all) return _applications;
    return _applications.where((a) {
      final s = _deriveState(a);
      if (_filter == _Filter.queued) return s == ApplicationState.queued;
      if (_filter == _Filter.inProgress)
        return s == ApplicationState.inProgress;
      if (_filter == _Filter.success) return s == ApplicationState.success;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF09090C),
      body: Stack(
        children: [
          GodBackground(scrollY: _scrollY),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    children: const [
                      _GlassIconButton(icon: Icons.arrow_back_rounded),
                      Expanded(child: SizedBox(width: 1)),
                      Padding(
                        padding: EdgeInsets.only(right: 35),
                        child: Text(
                          'Application en cours',
                          style: TextStyle(
                              color: white,
                              fontWeight: FontWeight.w600,
                              fontSize: 21),
                        ),
                      ),
                      Expanded(child: SizedBox(width: 1)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _StatsDock(
                      success: stats.success, pending: stats.pending),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _FilterDock(
                    value: _filter,
                    onChanged: (f) {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = f);
                    },
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const _CenterLoader()
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollUpdateNotification)
                              _scrollY.value = n.metrics.pixels;
                            return false;
                          },
                          child: RefreshIndicator(
                            onRefresh: _fetchApplications,
                            color: const Color(0xFF00E6C3),
                            child: ListView(
                              physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                              children: [
                                if (_applications.isEmpty)
                                  _EmptyState(onExplore: () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                            builder: (_) => HomePage()));
                                  })
                                else if (_visibleApps.isEmpty)
                                  const _NoMatchState()
                                else
                                  ..._visibleApps.map((app) {
                                    final id = app['application_id'] as String;
                                    final rawProgress =
                                        (app['progress'] as double)
                                            .clamp(0.0, 100.0);
                                    final state = _deriveState(app);
                                    final celebrate =
                                        state == ApplicationState.success &&
                                            !_celebrated.contains(id);
                                    return Dismissible(
                                      key: Key(id),
                                      direction: DismissDirection.horizontal,
                                      resizeDuration:
                                          null, // ✅ remove the resize animation (no “dirty size” reads)
                                      background: const _SwipeBg(
                                          alignment: Alignment.centerLeft),
                                      secondaryBackground: const _SwipeBg(
                                          alignment: Alignment.centerRight),
                                      confirmDismiss: (direction) async {
                                        final s = _deriveState(app);
                                        if (s == ApplicationState.success) {
                                          HapticFeedback.mediumImpact();
                                          return true;
                                        }
                                        return await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                backgroundColor:
                                                    const Color(0xFF121215),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18)),
                                                title: const Text(
                                                    'Confirmer la suppression',
                                                    style: TextStyle(
                                                        color: Colors.white)),
                                                content: const Text(
                                                    'Voulez-vous vraiment supprimer cette candidature ?',
                                                    style: TextStyle(
                                                        color: Colors.white70)),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(false),
                                                      child: const Text(
                                                          'Annuler',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white))),
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(true),
                                                      child: const Text(
                                                          'Supprimer',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .redAccent))),
                                                ],
                                              ),
                                            ) ??
                                            false;
                                      },
                                      onDismissed: (_) {
                                        HapticFeedback.heavyImpact();

                                        // ✅ mutate after this frame; avoids touching layout during dismiss
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {
                                            _applications.removeWhere((item) =>
                                                item['application_id'] == id);
                                          });
                                        });

                                        _hideApplicationOnServer(id);
                                      },
                                      child: NebulaJobCard(
                                        app: app,
                                        rootContext: context,
                                        state: state,
                                        progress: rawProgress,
                                        celebrate: celebrate,
                                        onCelebrateConsumed: () =>
                                            setState(() => _celebrated.add(id)),
                                      ),
                                    );
                                  }).toList(),
                              ],
                            ),
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
}

class _SwipplyWordmark extends StatelessWidget {
  const _SwipplyWordmark();
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) =>
          const LinearGradient(colors: [Color(0xFF00FFE1), Color(0xFF7CF9D2)])
              .createShader(rect),
      blendMode: BlendMode.srcIn,
      child: const Text(
        'Swipply',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            letterSpacing: 0.5, fontSize: 22, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  const _LivePill();
  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.94, end: 1.0)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
              colors: [Color(0xFFFF5A7A), Color(0xFFFFD66B)]),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFF5A7A).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: const [
          Icon(Icons.circle, size: 8, color: Colors.black),
          SizedBox(width: 6),
          Text('LIVE',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
        ]),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  const _GlassIconButton({required this.icon});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _FilterDock extends StatelessWidget {
  final _Filter value;
  final ValueChanged<_Filter> onChanged;
  const _FilterDock({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF121218), Color(0xFF14141C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Segment(
                label: 'Toutes',
                active: value == _Filter.all,
                onTap: () => onChanged(_Filter.all)),
            const SizedBox(width: 8),
            _Segment(
                label: 'En attente',
                active: value == _Filter.queued,
                onTap: () => onChanged(_Filter.queued)),
            const SizedBox(width: 8),
            _Segment(
                label: 'En cours',
                active: value == _Filter.inProgress,
                onTap: () => onChanged(_Filter.inProgress)),
            const SizedBox(width: 8),
            _Segment(
                label: 'Envoyées',
                active: value == _Filter.success,
                onTap: () => onChanged(_Filter.success)),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Segment(
      {required this.label, required this.active, required this.onTap});
  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _Segment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? const Color(0xFF0F1015)
              : const Color(0xFF0F1015).withOpacity(0.6),
          border: Border.all(
              color: active
                  ? const Color(0xFF00E6C3)
                  : Colors.white.withOpacity(0.08)),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: const Color(0xFF00E6C3).withOpacity(0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8))
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: active ? 1 : 0.7,
              child: Text(widget.label,
                  style: TextStyle(
                      color: active ? const Color(0xFF00E6C3) : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsDock extends StatelessWidget {
  final int success;
  final int pending;
  const _StatsDock({required this.success, required this.pending});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF121218), Color(0xFF14141C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          _StatTile(
              label: 'Réussies',
              icon: Icons.verified_rounded,
              color: const Color(0xFF30F7AF),
              value: success),
          const SizedBox(width: 10),
          _StatTile(
              label: 'En attente',
              icon: Icons.hourglass_bottom_rounded,
              color: const Color(0xFF52A9FF),
              value: pending),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int value;
  const _StatTile(
      {required this.label,
      required this.icon,
      required this.color,
      required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1015),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      color.withOpacity(0.9),
                      color.withOpacity(0.6)
                    ])),
                child: Icon(icon, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: value.toDouble()),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(v.toInt().toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.0)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class NebulaJobCard extends StatefulWidget {
  final Map<String, dynamic> app;
  final ApplicationState state;
  final BuildContext rootContext;
  final double progress;
  final bool celebrate;
  final VoidCallback? onCelebrateConsumed;
  const NebulaJobCard(
      {required this.app,
      required this.rootContext,
      required this.state,
      required this.progress,
      this.celebrate = false,
      this.onCelebrateConsumed});
  @override
  State<NebulaJobCard> createState() => _NebulaJobCardState();
}

class _NebulaJobCardState extends State<NebulaJobCard>
    with TickerProviderStateMixin {
  late final AnimationController borderC =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..repeat();
  late final AnimationController pressC = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 160));
  AnimationController? confettiC;
  late List<_ConfettiPiece> pieces;
  Offset _pointer = Offset.zero;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _maybeStartConfetti(initial: true);
    pieces = List.generate(36, (i) => _ConfettiPiece.seed(i));
  }

  @override
  void didUpdateWidget(covariant NebulaJobCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartConfetti();
    final p0 = oldWidget.progress;
    final p1 = widget.progress;
    void ping(double t, Future<void> Function() fx) {
      if (p0 < t && p1 >= t) fx();
    }

    ping(33, HapticFeedback.lightImpact);
    ping(66, HapticFeedback.mediumImpact);
    ping(100, HapticFeedback.heavyImpact);
  }

  void _maybeStartConfetti({bool initial = false}) {
    if (widget.celebrate) {
      confettiC?.dispose();
      confettiC = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1400))
        ..forward().whenComplete(() => widget.onCelebrateConsumed?.call());
    }
  }

  @override
  void dispose() {
    borderC.dispose();
    pressC.dispose();
    confettiC?.dispose();
    super.dispose();
  }

  String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), ' ') // drop tags
      .replaceAll(RegExp(r'&nbsp;|&amp;|&quot;|&#39;|&lt;|&gt;'),
          ' ') // common entities -> space
      .replaceAll(RegExp(r'\s+'), ' ') // collapse whitespace
      .trim();

  String _pickDescription(Map<String, dynamic> j) {
    final d = (j['description'] ?? '').toString().trim();
    if (d.isNotEmpty) return d;
    final sd = (j['short_description'] ?? '').toString().trim();
    return sd;
  }

// ---- DEBUG HELPERS ----------------------------------------------------------
  void dbg(Object? msg) {
    if (kDebugMode) debugPrint('[apps] $msg');
  }

  /// short preview for long strings in logs
  String prev(String? s, {int n = 120}) {
    if (s == null) return 'null';
    final t = s.replaceAll('\n', ' ');
    return (t.length <= n) ? t : '${t.substring(0, n)}…';
  }
// ----------------------------------------------------------------------------

  void _showDetailsSheet(
      Map<String, dynamic> job, Color color, String status, String titleText) {
    final String desc = _pickDescription(job); // leave as-is (see part B)

    showModalBottomSheet(
      context: widget.rootContext, // <— use stable context
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.38,
          maxChildSize: 0.9,
          builder: (ctx, scroll) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1116).withOpacity(0.86),
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.08))),
                  ),
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(999))),
                          ]),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Text(
                                titleText, // <- EXACT SAME title used on the card
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: -6, children: [
                        if ((job['company_name']?.toString() ?? '').isNotEmpty)
                          _PillChip(
                              icon: Icons.apartment_rounded,
                              label: job['company_name'].toString()),
                        if ((job['location']?.toString() ?? '').isNotEmpty)
                          _PillChip(
                              icon: Icons.place_rounded,
                              label: job['location'].toString()),
                        if ((job['contract_type']?.toString() ?? '').isNotEmpty)
                          _PillChip(
                              icon: Icons.badge_rounded,
                              label: job['contract_type'].toString()),
                      ]),
                      const SizedBox(height: 16),
                      _StageTimeline(
                          value: (widget.progress / 100), color: color),
                      const SizedBox(height: 18),
                      _StatusPill(text: status, color: color),
                      const SizedBox(height: 18),
                      Text(
                        desc.isNotEmpty ? desc : 'Aucune description fournie.',
                        style:
                            const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.app['JobListings'] as Map<String, dynamic>? ?? {};
    final logo = job['company_logo_url'] as String? ?? '';
    final company = job['company_name']?.toString() ?? '';
    late final Color color;
    late final String status;
    late final String tagText;
    if (widget.state == ApplicationState.success) {
      color = const Color(0xFF3AF9B8);
      status = 'Envoyé';
      tagText = 'OK';
    } else if (widget.state == ApplicationState.queued) {
      color = const Color(0xFF59A8FF);
      status = 'En attente';
      tagText = '…';
    } else {
      color = const Color(0xFF7DD3FF);
      status = '${widget.progress.toInt()}% • En cours';
      tagText = '${widget.progress.toInt()}%';
    }
    final picked = _pickTitle(job);
    final title = picked.isNotEmpty
        ? picked
        : (company.isNotEmpty ? company : 'France Travail');

    return AnimatedBuilder(
      animation: borderC,
      builder: (_, __) {
        final scale = 1 - (pressC.value * 0.02);
        final tilt = _computeTilt();
        return Listener(
          onPointerMove: (e) => _updatePointer(e.localPosition),
          onPointerHover: (e) => _updatePointer(e.localPosition),
          onPointerDown: (e) => pressC.forward(),
          onPointerUp: (e) => pressC.reverse(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _size = Size(constraints.maxWidth, 0);
              return Transform(
                alignment: Alignment.center,
                transform: _perspective()
                  ..rotateX(tilt.dy)
                  ..rotateY(-tilt.dx)
                  ..scale(scale),
                child: Stack(
                  children: [
                    CustomPaint(
                      painter:
                          _NeonBorderPainter(t: borderC.value, color: color),
                      child: InkWell(
                        onTap: () =>
                            _showDetailsSheet(job, color, status, title),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                                colors: [Color(0xFF141418), Color(0xFF191922)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 16))
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(colors: [
                                                color.withOpacity(0.25),
                                                Colors.transparent
                                              ])),
                                        ),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: SizedBox(
                                              width: 56,
                                              height: 56,
                                              child: CompanyLogo(logo)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Title takes the leftover space and ellipsizes
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 10),

                                              // Reserved, fixed slot for the status/Lottie
                                              SizedBox(
                                                width:
                                                    56, // lock the width so it never steals from title
                                                height:
                                                    56, // keeps visual rhythm with your logo size
                                                child: Align(
                                                  alignment: Alignment.topRight,
                                                  child: FittedBox(
                                                    fit: BoxFit
                                                        .scaleDown, // safety: if a variant is slightly larger
                                                    child: _CornerStatus(
                                                      state: widget.state,
                                                      color: color,
                                                      tagText:
                                                          tagText, // e.g. "45%" or "OK"
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                if (company.isNotEmpty)
                                                  _PillChip(
                                                      icon: Icons
                                                          .apartment_rounded,
                                                      label: company),
                                                if ((job['location']
                                                            ?.toString() ??
                                                        '')
                                                    .isNotEmpty)
                                                  _PillChip(
                                                      icon: Icons.place_rounded,
                                                      label: job['location']
                                                          .toString()),
                                              ]),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                    height: 22,
                                    child: CustomPaint(
                                        painter: _BezierWaveProgress(
                                            t: borderC.value,
                                            color: color,
                                            value: widget.progress / 100))),
                                const SizedBox(height: 10),
                                _StatusPill(text: status, color: color),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.state == ApplicationState.inProgress ||
                        widget.state == ApplicationState.queued)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              _AffordanceArrow(left: true),
                              _AffordanceArrow(left: false),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _updatePointer(Offset p) => setState(() => _pointer = p);
  Matrix4 _perspective() {
    final m = Matrix4.identity();
    m.setEntry(3, 2, 0.0012);
    return m;
  }

  Offset _computeTilt() {
    if (_size.width == 0) return Offset.zero;
    final dx = ((_pointer.dx / _size.width) - 0.5) * 0.18;
    final dy = 0.0 - ((_pointer.dy / 160.0).clamp(0.0, 1.0) - 0.5) * 0.18;
    return Offset(dx, dy);
  }
}

class _CornerStatus extends StatelessWidget {
  final ApplicationState state;
  final Color color;
  final String tagText;
  const _CornerStatus({
    required this.state,
    required this.color,
    required this.tagText,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ApplicationState.success:
        return _SuccessBadge(color: color);
      case ApplicationState.inProgress:
        return _ProgressBadge(color: color, tagText: tagText);
      case ApplicationState.queued:
      default:
        return _QueuedBadge(color: color);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS — pulsing halo + glass orb + Lottie check
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessBadge extends StatefulWidget {
  final Color color;
  const _SuccessBadge({required this.color});
  @override
  State<_SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<_SuccessBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: SizedBox(
          width: 55,
          height: 55,
          child: Lottie.asset(
            check, // your ✅ lottie
            repeat: true,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double t; // 0..1
  final Color color;
  _PulseRingPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // two staggered rings for richer pulse
    void ring(double phase) {
      final p = ((t + phase) % 1.0);
      final scale = 1.0 + 0.35 * p;
      final alpha = (1.0 - p).clamp(0.0, 1.0);
      final r = size.width / 2 * scale;
      final center = Offset(size.width / 2, size.height / 2);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - p)
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            color.withOpacity(0.55 * alpha),
            Colors.transparent,
          ],
          stops: const [0.2, 0.5, 0.8],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }

    ring(0.0);
    ring(0.5);
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter old) =>
      old.t != t || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// IN PROGRESS — neon pill + subtle rotating halo behind it
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBadge extends StatefulWidget {
  final Color color;
  final String tagText;
  const _ProgressBadge({required this.color, required this.tagText});
  @override
  State<_ProgressBadge> createState() => _ProgressBadgeState();
}

class _ProgressBadgeState extends State<_ProgressBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // rotating sweep halo behind the pill
        Positioned(
          right: -4,
          child: AnimatedBuilder(
            animation: c,
            builder: (_, __) => Transform.rotate(
              angle: c.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(64, 64),
                painter: _SweepHaloPainter(color: widget.color),
              ),
            ),
          ),
        ),
        // existing pill with our brand styling
        _EdgeBadge(text: widget.tagText, color: widget.color),
      ],
    );
  }
}

class _SweepHaloPainter extends CustomPainter {
  final Color color;
  _SweepHaloPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(.45),
          color.withOpacity(.0),
        ],
        stops: const [0.0, 0.25, 0.5],
      ).createShader(Offset.zero & size);
    final r = size.width / 2.2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), r, stroke);
  }

  @override
  bool shouldRepaint(covariant _SweepHaloPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUED — glass capsule + rotating neon ring + Lottie loader
// ─────────────────────────────────────────────────────────────────────────────
class _QueuedBadge extends StatefulWidget {
  final Color color;
  const _QueuedBadge({required this.color});
  @override
  State<_QueuedBadge> createState() => _QueuedBadgeState();
}

class _QueuedBadgeState extends State<_QueuedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // rotating neon ring
        AnimatedBuilder(
          animation: c,
          builder: (_, __) => Transform.rotate(
            angle: c.value * 2 * math.pi,
            child: CustomPaint(
              size: const Size(47, 47),
              painter: _ArcRingPainter(color: widget.color),
            ),
          ),
        ),
        // glass capsule
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: widget.color.withOpacity(.45), width: 1),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withOpacity(.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: ClipOval(
            child: Center(
              child: SizedBox(
                width: 50,
                height: 50,
                child: Lottie.asset(
                  loadinggg, // your loader lottie
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  final Color color;
  _ArcRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2.1;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(center, r, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(.0),
          color.withOpacity(.85),
          color.withOpacity(.0)
        ],
        stops: const [0.05, 0.25, 0.45],
      ).createShader(Offset.zero & size);

    // full circle with gradient head/tail looks like a moving arc
    canvas.drawCircle(center, r, arc);
  }

  @override
  bool shouldRepaint(covariant _ArcRingPainter old) => old.color != color;
}

String _pickTitle(Map<String, dynamic> j) {
  for (final k in const ['title', 'job_title', 'position', 'role']) {
    final v = j[k]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return '';
}

class _PillChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PillChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF23232B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // <- minimal width
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            // <- shrink to content, allow ellipsis
            fit: FlexFit.loose,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonBorderPainter extends CustomPainter {
  final double t;
  final Color color;
  _NeonBorderPainter({required this.t, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final r =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22));
    final base = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(r, base);
    final shader = SweepGradient(
      colors: [Colors.transparent, color.withOpacity(0.8), Colors.transparent],
      stops: const [0.25, 0.5, 0.75],
      transform: GradientRotation(2 * math.pi * t),
    ).createShader(Offset.zero & size);
    final glow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(r.deflate(0.5), glow);
  }

  @override
  bool shouldRepaint(covariant _NeonBorderPainter old) =>
      old.t != t || old.color != color;
}

class _BezierWaveProgress extends CustomPainter {
  final double t;
  final Color color;
  final double value;
  _BezierWaveProgress(
      {required this.t, required this.color, required this.value});
  @override
  void paint(Canvas canvas, Size size) {
    final track =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(11));
    canvas.drawRRect(track, Paint()..color = const Color(0xFF2B2B31));
    final w = (size.width * value).clamp(0.0, size.width);
    if (w <= 0.0) {
      final bandW = size.width * 0.22;
      final x = (t * size.width * 1.2) % (size.width + bandW) - bandW;
      final rect = Rect.fromLTWH(x, 0, bandW, size.height);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.0)
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(11)), paint);
      return;
    }
    final clip = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, size.height), const Radius.circular(11));
    canvas.save();
    canvas.clipRRect(clip);
    final grad = Paint()
      ..shader = LinearGradient(
              colors: [color.withOpacity(0.85), color],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight)
          .createShader(Rect.fromLTWH(0, 0, w, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), grad);
    final path = Path();
    final amp = 6.0;
    final freq = 2.1;
    final speed = t * 2 * math.pi;
    for (double x = 0; x <= w; x += 4) {
      final y = size.height / 2 +
          amp * math.sin((x / size.width * freq * 2 * math.pi) + speed);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path, wavePaint);
    final headX = w - 6;
    final spark = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
        Offset(headX, size.height / 2), 3 + 2 * math.sin(speed), spark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BezierWaveProgress old) =>
      old.t != t || old.color != color || old.value != value;
}

class _ConfettiPiece {
  final double dx;
  final double size;
  final double rot;
  final Color color;
  _ConfettiPiece(this.dx, this.size, this.rot, this.color);
  factory _ConfettiPiece.seed(int i) {
    final size = 4.0 + (i % 6).toDouble();
    final rot = (i * 19 % 360) * math.pi / 180;
    final palette = [
      const Color(0xFF3AF9B8),
      const Color(0xFF59A8FF),
      const Color(0xFFFF5A7A),
      const Color(0xFFFFD66B)
    ];
    return _ConfettiPiece(
        (i * 37 % 100) / 100.0, size, rot, palette[i % palette.length]);
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<_ConfettiPiece> pieces;
  _ConfettiPainter({required this.t, required this.pieces});
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final x = p.dx * size.width;
      final y = Curves.easeOut.transform(t) * size.height;
      final paint = Paint()..color = p.color.withOpacity(1 - t);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + t * 6.0);
      final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2));
      canvas.drawRRect(r, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.t != t || old.pieces != pieces;
}

class _StageTimeline extends StatelessWidget {
  final double value;
  final Color color;
  const _StageTimeline({required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final a = v >= 0.0;
    final b = v >= 0.33;
    final c = v >= 0.66;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _Dot(active: a, color: color),
          Expanded(child: Container(height: 2, color: const Color(0xFF2B2B31))),
          _Dot(active: b, color: color),
          Expanded(child: Container(height: 2, color: const Color(0xFF2B2B31))),
          _Dot(active: c, color: color),
        ]),
        const SizedBox(height: 8),
        const Text('En attente  •  Formulaire  •  Validation',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  final Color color;
  const _Dot({required this.active, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : const Color(0xFF2B2B31),
        boxShadow: active
            ? [
                BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 0)
              ]
            : null,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _AffordanceArrow extends StatefulWidget {
  final bool left;
  const _AffordanceArrow({required this.left});
  @override
  State<_AffordanceArrow> createState() => _AffordanceArrowState();
}

class _AffordanceArrowState extends State<_AffordanceArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.0, end: 0.35)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(
            widget.left
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: Colors.white,
            size: 28),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Alignment alignment;
  const _SwipeBg({required this.alignment});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
          color: const Color(0xFFFF5470),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            const Icon(Icons.delete_forever, color: Colors.white, size: 28),
            const SizedBox(width: 8),
          ],
          const Text('Remove',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: 8),
            const Icon(Icons.delete_forever, color: Colors.white, size: 28),
          ],
        ],
      ),
    );
  }
}

class _CenterLoader extends StatelessWidget {
  const _CenterLoader();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(height: 12),
          SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                  minHeight: 6,
                  color: Color(0xFF00E6C3),
                  backgroundColor: Color(0xFF23232B))),
          SizedBox(height: 14),
          Text('Synchronisation…',
              style: TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.search_off_rounded, color: Colors.white38, size: 48),
          SizedBox(height: 10),
          Text('Aucun résultat pour ce filtre',
              style: TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onExplore;
  const _EmptyState({required this.onExplore});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.08),
        Lottie.asset(notFound, height: 260, width: 260),
        const SizedBox(height: 10),
        const Text("Vous n'avez aucune application en cours.",
            style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E6C3),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: onExplore,
          child: const Text('Trouver des offres',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _EdgeBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _EdgeBadge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    final display = (text.isEmpty) ? '…' : text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Text(
        display,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}
