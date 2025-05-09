import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';

class ApplicationsInProgressPage extends StatefulWidget {
  @override
  State<ApplicationsInProgressPage> createState() =>
      _ApplicationsInProgressPageState();
}

class _ApplicationsInProgressPageState
    extends State<ApplicationsInProgressPage> {
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
        print("❌ User not logged in.");
        setState(() => isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(
            '$BASE_URL_AUTH/api/applications-in-progress?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> applications = data['applications'] ?? [];

        setState(() {
          _applications = applications
              .map<Map<String, dynamic>>((app) => {
                    'JobListings': app['JobListings'],
                    'progress_status': app['progress_status'] ?? 0,
                    'application_status': app['application_status'] ?? '',
                  })
              .toList();
          isLoading = false;
        });
      } else {
        print("❌ Failed to fetch applications: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error fetching applications: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: white,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.greenAccent,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInterviewNotification(), // Always visible for testing
                const SizedBox(height: 20),
                _applications.isNotEmpty
                    ? const SizedBox(height: 16)
                    : const Text(
                        "Vous n'avez aucune application en cours.",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                ..._applications.map((app) => _buildJobCard(app)).toList(),
              ],
            ),
    );
  }

  Widget _buildInterviewNotification() {
    // This notification will always appear (for testing)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0E13), Color(0xFF111519)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.celebration_rounded,
              color: Colors.greenAccent, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Félicitations !!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Vous avez un entretien avec NEXORA.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 4, // Prevents text from overflowing
                        overflow: TextOverflow
                            .ellipsis, // Adds "..." if text is too long
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: Colors.greenAccent, width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          // Redirect to interview details (implement as needed)
                        },
                        child: const Text(
                          "Voir les détails",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> app) {
    final job = app['JobListings'];
    final jobTitle = job?['title'] ?? 'Titre de l\'emploi';
    final companyName = job?['company'] ?? 'Entreprise inconnue';
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
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: companyLogo.isNotEmpty
                ? Image.network(companyLogo,
                    width: 60, height: 60, fit: BoxFit.cover)
                : Container(width: 60, height: 60, color: Colors.grey[800]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jobTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(companyName,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(location,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
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
                Text('${(progress * 100).toStringAsFixed(0)}% complet',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
