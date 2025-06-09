import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/env.dart';

class JobApplicationsProgress extends StatefulWidget {
  @override
  State<JobApplicationsProgress> createState() =>
      _JobApplicationsProgressState();
}

class _JobApplicationsProgressState extends State<JobApplicationsProgress> {
  List<Map<String, dynamic>> _applications = [];
  bool isLoading = true;
  final Map<String, double> _lastProgress = {};
  final Map<String, DateTime> _lastChange = {};
  final Set<String> _retryingIds = {};
  final Map<String, int> _retryCount = {};
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _loadBackupEmail();
    _poller = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchApplications(),
    );
    _fetchApplications();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _hideApplicationOnServer(String applicationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final uri =
        Uri.parse('$BASE_URL_AUTH/api/applications/$applicationId/hide');
    final res = await http.post(
      // ← use post, not patch
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      debugPrint('Failed to hide application: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> _loadBackupEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');
    if (userId == null || token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL_AUTH/api/users/$userId/second-email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final backup = body['second_email'] as String?;
        if (backup != null && backup.isNotEmpty) {
          await prefs.setString('second_email', backup);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchApplications() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');
    if (userId == null || token == null) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }
    http.Response res;
    try {
      res = await http.get(
        Uri.parse(
          '$BASE_URL_AUTH/api/applications-in-progress-visible?user_id=$userId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }
    if (res.statusCode != 200) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final rawApps = (body['applications'] as List<dynamic>?) ?? [];
    final now = DateTime.now();
    final nextApps = <Map<String, dynamic>>[];
    for (var raw in rawApps) {
      final id = raw['application_id'] as String;
      final progress = (raw['progress_status'] as num?)?.toDouble() ?? 0.0;
      final error = raw['error_message'] as String?;
      if (_lastProgress[id] == null || _lastProgress[id] != progress) {
        _lastChange[id] = now;
        _lastProgress[id] = progress;
      }
      nextApps.add({
        'application_id': id,
        'JobListings': raw['JobListings'],
        'progress': progress,
        'error': error,
      });
    }
    if (!mounted) return;
    setState(() {
      _applications = nextApps;
      isLoading = false;
    });
    for (var app in _applications) {
      final id = app['application_id'] as String;
      final prog = app['progress'] as double;
      final err = app['error'] as String?;
      final lastTime = _lastChange[id] ?? now;
      final stuckFor = now.difference(lastTime);
      final count = _retryCount[id] ?? 0;
      final isFailed = (prog == 100 && err != null) ||
          stuckFor > const Duration(seconds: 30);
      if (!isFailed) continue;
      final jobId =
          (app['JobListings'] as Map<String, dynamic>)['job_id'] as String;
      if (count == 0) {
        _retryApplication(jobId, id);
      } else if (count == 1) {
        final backup = await prefs.getString('second_email');
        if (backup != null && backup.isNotEmpty) {
          _retryApplication(jobId, id);
        }
      }
    }
  }

  Future<void> _retryApplication(String jobId, String appId) async {
    final count = _retryCount[appId] ?? 0;
    if (count >= 2) {
      if (!mounted) return;
      return _showCannotApplyDialog(context);
    }
    _retryCount[appId] = count + 1;
    if (!mounted) return;
    setState(() => _retryingIds.add(appId));
    final token = await SharedPreferences.getInstance()
        .then((prefs) => prefs.getString('token'));
    if (token == null) {
      if (!mounted) return;
      setState(() => _retryingIds.remove(appId));
      return;
    }
    try {
      final body = <String, dynamic>{
        'application_id': appId,
        if (_retryCount[appId] == 2)
          'second_email': await SharedPreferences.getInstance()
              .then((prefs) => prefs.getString('second_email')),
      };
      await http.post(
        Uri.parse('$BASE_URL_AUTH/api/auto-register-apply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
    } finally {
      if (!mounted) return;
      setState(() => _retryingIds.remove(appId));
    }
  }

  void _showCannotApplyDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        title: const Text(
          'Impossible de postuler',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Vous avez atteint le nombre maximum de tentatives pour cette offre.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBackupEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('second_email', email);
    final token = prefs.getString('token');
    final userId = prefs.getString('user_id');
    if (token == null || userId == null) return;
    final uri = Uri.parse('$BASE_URL_AUTH/api/users/$userId/second-email');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'second_email': email}),
    );
    if (response.statusCode != 200) {}
  }

  void _showBackupEmailDialog(BuildContext context) {
    final TextEditingController _emailController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: const Color.fromARGB(255, 27, 27, 27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined, color: Colors.redAccent, size: 40),
              const SizedBox(height: 20),
              const Text(
                "Adresse e-mail de secours",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Entrez votre e-mail de secours',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2B2B2B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                      onPressed: () async {
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          await _saveBackupEmail(email);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Enregistrer",
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
                        "Annuler",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Applications en cours',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        leading: BackButton(color: theme.colorScheme.secondary),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            )
          : RefreshIndicator(
              onRefresh: _fetchApplications,
              color: Colors.tealAccent,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (_applications.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.1,
                        ),
                        Lottie.asset(notFound, height: 300, width: 300),
                        Text(
                          "Vous n'avez aucune application en cours.",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    ..._applications.map((app) {
                      final id = app['application_id'] as String;
                      // Determine this card’s state:
                      final rawProgress =
                          (app['progress'] as double).clamp(0.0, 100.0);
                      final error = app['error'] as String?;
                      final lastTime = _lastChange[id] ?? DateTime.now();
                      final isStuck = DateTime.now().difference(lastTime) >
                          const Duration(seconds: 10);

                      if (rawProgress == 100 && error == null) {
                      } else if (rawProgress == 100 && error != null) {
                      } else if (isStuck) {
                      } else {}

                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Transform.translate(
                                offset: const Offset(5, 0),
                                child: Transform.rotate(
                                  angle: -0.2,
                                  child: Icon(
                                    Icons.delete_forever,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Remove',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          // If already succeeded, skip dialog:
                          final rawProgress =
                              (app['progress'] as double).clamp(0.0, 100.0);
                          final error = app['error'] as String?;
                          final lastTime = _lastChange[id] ?? DateTime.now();
                          final isStuck = DateTime.now().difference(lastTime) >
                              const Duration(seconds: 10);

                          ApplicationState state;
                          if (rawProgress == 100 && error == null) {
                            state = ApplicationState.success;
                          } else if (rawProgress == 100 && error != null) {
                            state = ApplicationState.failWithError;
                          } else if (isStuck) {
                            state = ApplicationState.failStuck;
                          } else {
                            state = ApplicationState.inFlight;
                          }

                          if (state == ApplicationState.success) {
                            // No confirmation needed for succeeded applications
                            return true;
                          }

                          // Otherwise, show confirm dialog as before
                          return await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor:
                                  const Color.fromARGB(255, 27, 27, 27),
                              title: const Text(
                                'Confirmer la suppression',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'Voulez-vous vraiment supprimer cette candidature ?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text(
                                    'Annuler',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text(
                                    'Supprimer',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          // 1) Remove locally so UI updates immediately:
                          setState(() {
                            _applications.removeWhere(
                                (item) => item['application_id'] == id);
                          });

                          // 2) Tell backend to hide this application permanently:
                          _hideApplicationOnServer(id);
                        },
                        child: _buildJobCard(app, theme),
                      );
                    }).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> app, ThemeData theme) {
    final job = app['JobListings'] as Map<String, dynamic>? ?? {};
    final appId = app['application_id'] as String;
    final rawProgress = (app['progress'] as double).clamp(0.0, 100.0);
    final error = app['error'] as String?;
    final jobId = job['job_id'] as String? ?? '';
    final lastTime = _lastChange[appId] ?? DateTime.now();
    final isStuck =
        DateTime.now().difference(lastTime) > const Duration(seconds: 10);

    // 1) Determine state
    ApplicationState state;
    if (rawProgress == 100 && error == null) {
      state = ApplicationState.success;
    } else if (rawProgress == 100 && error != null) {
      state = ApplicationState.failWithError;
    } else if (isStuck) {
      state = ApplicationState.failStuck;
    } else {
      state = ApplicationState.inFlight;
    }

    // 2) Map state → color & text
    late Color stateColor;
    late String statusText;
    switch (state) {
      case ApplicationState.success:
        stateColor = Color(0xFF69F0AE);
        statusText = "Envoyé";
        break;
      case ApplicationState.failWithError:
        stateColor = Colors.redAccent;
        statusText = "Échec : $error";
        break;
      case ApplicationState.failStuck:
        stateColor = Colors.redAccent;
        statusText = "Échec (bloqué)";
        break;
      case ApplicationState.inFlight:
      default:
        stateColor = Colors.blueAccent;
        statusText = "${rawProgress.toStringAsFixed(0)}%";
    }

    final isRetrying = _retryingIds.contains(appId);
    final retries = _retryCount[appId] ?? 0;
    final canRetry = retries < 2;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF262626),
        child: InkWell(
          onTap: () {
            // Optional: add on-tap behavior (e.g., show detailed info)
          },
          splashColor: Colors.white12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header: Logo, Title & Status Icon ───────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (job['company_logo_url'] as String?)?.isNotEmpty ==
                              true
                          ? Image.network(
                              job['company_logo_url'],
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 54,
                                height: 54,
                                color: Colors.grey[800],
                              ),
                            )
                          : Container(
                              width: 54, height: 54, color: Colors.grey[800]),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        job['title'] as String? ?? 'Titre indisponible',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: (state == ApplicationState.success)
                          ? Lottie.asset(
                              check,
                              width: 50,
                              height: 50,
                              fit: BoxFit.contain,
                            )
                          : (state == ApplicationState.failWithError ||
                                  state == ApplicationState.failStuck)
                              ? Lottie.asset(
                                  errorn,
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.contain,
                                )
                              : const SizedBox(
                                  key: ValueKey('inflight'),
                                  width: 0,
                                  height: 0,
                                ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.grey, thickness: 0.3),

              // ─── Progress Row: Bar + Percentage Label ─────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: rawProgress / 100),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, animatedValue, _) =>
                              LinearProgressIndicator(
                            value: animatedValue,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade800,
                            valueColor: AlwaysStoppedAnimation(stateColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "${rawProgress.toStringAsFixed(0)}%",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Status Chip ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),

                    // 1) Constrain the maximum width of the container.
                    //    Here we subtract 32 for the horizontal padding (16 + 16).
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 32,
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min, // 2) Shrink‐wrap
                      children: [
                        Icon(
                          (state == ApplicationState.success)
                              ? Icons.check
                              : (state == ApplicationState.failWithError ||
                                      state == ApplicationState.failStuck)
                                  ? Icons.error
                                  : Icons.autorenew,
                          size: 16,
                          color: stateColor,
                        ),
                        const SizedBox(width: 6),

                        // 3) Wrap Text in Flexible (not Expanded) so it can ellipsize.
                        Flexible(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: stateColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Retry / Backup Button ───────────────────────────────────────────────
              if (state == ApplicationState.failWithError ||
                  state == ApplicationState.failStuck)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: canRetry
                        ? SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                primary: theme.colorScheme
                                    .secondary, // simple professional color
                                onPrimary: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              onPressed: isRetrying
                                  ? null
                                  : () => _retryApplication(jobId, appId),
                              icon: isRetrying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 20),
                              label: Text(
                                isRetrying ? 'Réessai...' : 'Réessayer',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _showBackupEmailDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Color(0xFFD32F2F),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Échec',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                  ),
                ),
              SizedBox(
                height: 15,
              )
            ],
          ),
        ),
      ),
    );
  }
}

enum ApplicationState {
  inFlight,
  success,
  failWithError,
  failStuck,
}
