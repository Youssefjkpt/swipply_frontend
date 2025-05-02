import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApplicationsInProgressPage extends StatefulWidget {
  @override
  State<ApplicationsInProgressPage> createState() =>
      _ApplicationsInProgressPageState();
}

class _ApplicationsInProgressPageState
    extends State<ApplicationsInProgressPage> {
  List<dynamic> _applications = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
    _pollingTimer =
        Timer.periodic(Duration(seconds: 1), (_) => _fetchApplications());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchApplications() async {
    try {
      final response = await http
          .get(Uri.parse('http://YOUR_BACKEND/api/applications-in-progress'));
      if (response.statusCode == 200) {
        final List<dynamic> apps = json.decode(response.body);
        final now = DateTime.now();

        final filtered = apps.where((app) {
          final status = app['application_status'] ?? '';
          final createdAt =
              DateTime.tryParse(app['application_date'] ?? '') ?? now;
          final isSuccess = status.toLowerCase() == 'success';
          final age = now.difference(createdAt).inMilliseconds;
          return !(isSuccess && age > 5000);
        }).toList();

        setState(() => _applications = filtered);
      }
    } catch (e) {
      print('❌ Fetch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Applications in Progress')),
      body: _applications.isEmpty
          ? Center(child: Text('No applications in progress'))
          : ListView.builder(
              itemCount: _applications.length,
              itemBuilder: (context, index) {
                final app = _applications[index];
                final job = app['JobListings'];
                final jobTitle = job?['title'] ?? 'Job Title';
                final rawProgress =
                    (app['progress_status'] ?? 0).toDouble().clamp(0, 100);
                final progress = rawProgress / 100;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(jobTitle,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        SizedBox(height: 12),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade300,
                              color: value == 1.0 ? Colors.green : Colors.blue,
                            );
                          },
                        ),
                        SizedBox(height: 8),
                        Text('${rawProgress.toStringAsFixed(0)}% complete',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black87)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
