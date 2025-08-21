// ignore_for_file: unused_field

import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/home_page.dart';
import 'package:swipply/services/api_service.dart';
import 'package:geocoding/geocoding.dart';

enum SalaryPeriod { hourly, monthly, yearly, unknown }

String salaryPeriodText(dynamic raw, {String fallback = 'inconnu'}) {
  final r = _parseSalary(raw);
  return r.periodLabelFr.isEmpty ? fallback : r.periodLabelFr;
}

class SalaryParseResult {
  final double? min;
  final double? max;
  final SalaryPeriod period;
  final String periodLabelFr;
  SalaryParseResult(
      {this.min, this.max, required this.period, required this.periodLabelFr});
}

String salaryPeriodTextSmart(dynamic raw) {
  final r = _parseSalary(raw);
  if (r.period != SalaryPeriod.unknown) return r.periodLabelFr;
  final v = r.min;
  if (v == null) return 'Selon Profil';
  if (v < 50) return 'horaire';
  if (v < 10000) return 'mensuel';
  return 'annuel';
}

SalaryParseResult _parseSalary(dynamic raw) {
  final input = (raw ?? '').toString();
  final s = input.toLowerCase();
  SalaryPeriod period = SalaryPeriod.unknown;
  String label = '';
  if (RegExp(r'(/|\bpar\b)\s*(h|heure|heures)\b').hasMatch(s)) {
    period = SalaryPeriod.hourly;
    label = 'horaire';
  } else if (RegExp(r'\bmois\b|\bmensuel(le)?\b|/\s*m(ois)?\b').hasMatch(s)) {
    period = SalaryPeriod.monthly;
    label = 'mensuel';
  } else if (RegExp(r'\ban(n|nuelle?|née)s?\b|\bannuel(le)?\b|/\s*a(n|nnée)?\b')
      .hasMatch(s)) {
    period = SalaryPeriod.yearly;
    label = 'annuel';
  }

  final numRe = RegExp(
      r'(\d{1,3}(?:[ \u00A0\u202F]?\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?)');
  final matches = numRe.allMatches(input).map((m) => m.group(0)!).toList();

  double? toDouble(String v) {
    final cleaned =
        v.replaceAll(RegExp(r'[ \u00A0\u202F]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  final values = matches.map(toDouble).whereType<double>().toList();
  final double? min = values.isNotEmpty ? values.first : null;
  final double? max = values.length >= 2 ? values[1] : null;

  return SalaryParseResult(
      min: min, max: max, period: period, periodLabelFr: label);
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  final r2 = (v * 100).roundToDouble() / 100;
  var s = r2.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'([.,]\d*?)0+$'), r'$1');
  s = s.replaceFirst(RegExp(r'[.,]$'), '');
  return s;
}

String _formatSalary(dynamic raw) {
  final r = _parseSalary(raw);
  if (r.min == null) return '';
  final amount = r.max != null && r.max != r.min
      ? '${_fmtNum(r.min!)}–${_fmtNum(r.max!)} €'
      : '${_fmtNum(r.min!)} €';
  final unit = r.periodLabelFr.isNotEmpty ? ' • ${r.periodLabelFr}' : '';
  return amount + unit;
}

class JobInformations extends StatefulWidget {
  final Map<String, dynamic> job;
  JobInformations({super.key, required this.job});

  @override
  State<JobInformations> createState() => _JobInformationsState();
}

class _JobInformationsState extends State<JobInformations> {
  int selectedTab = 1;
  void requestLocationPermission() async {
    await Permission.location.request();
  }

  String _mapContractType(String? raw) {
    if (raw == null) return '—';
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'cdi':
        return 'Contrat à durée indéterminée';
      case 'cdd':
        return 'Contrat à durée déterminée';
      // optional extras, keep if your DB returns them
      case 'interim':
      case 'intérim':
        return 'Contrat d’intérim';
      case 'alternance':
        return 'Contrat en alternance';
      case 'apprentissage':
        return 'Contrat d’apprentissage';
      case 'stage':
        return 'Stage';
      default:
        // Fallback: capitalize the raw string
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  String _mapEmploymentType(String? raw) {
    if (raw == null) return '—';
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'full_time':
      case 'full-time':
      case 'plein':
      case 'temps plein':
        return 'Temps plein';
      case 'part_time':
      case 'part-time':
      case 'partiel':
      case 'temps partiel':
        return 'Temps partiel';
      default:
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  String _formatSalary(dynamic salary) {
    if (salary == null) return '—';
    // Common cases:
    if (salary is String)
      return salary; // e.g. "12,50 €/h" or "2 100 € brut/mois"
    if (salary is num) return '${salary.toStringAsFixed(0)} €';
    if (salary is Map) {
      final min = salary['min'];
      final max = salary['max'];
      final period =
          (salary['period'] ?? '').toString(); // "hour", "month", "year"
      final currency = (salary['currency'] ?? '€').toString();
      String per = '';
      switch (period.toLowerCase()) {
        case 'hour':
          per = '/h';
          break;
        case 'month':
          per = '/mois';
          break;
        case 'year':
          per = '/an';
          break;
      }
      if (min != null && max != null) {
        return '$min–$max $currency$per';
      } else if (min != null) {
        return 'À partir de $min $currency$per';
      } else if (max != null) {
        return 'Jusqu’à $max $currency$per';
      }
    }
    return salary.toString();
  }

  List<Map<String, dynamic>> jobs = [];
  bool isExpanded = false; // To manage "Read more" functionality
  bool showAll = false;
  LatLng? _jobLatLng;
  bool _isGeocoding = true;
  bool _disableScroll = false;
  Future<void> saveJob() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final jobId = widget.job["job_id"];

    if (userId == null || jobId == null) {
      print('❌ Missing user ID or job ID');
      return;
    }

    try {
      final response = await ApiService.saveJob(userId: userId, jobId: jobId);
      if (response.statusCode == 200) {
        print('✅ Job saved successfully.');
      } else {
        print('❌ Failed to save job. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error saving job: $e');
    }
  }

  bool isSaved = false;
  Future<void> _resolveLocation() async {
    final locationText = widget.job["location"] ?? "Paris, France";

    try {
      final List<Location> locations = await locationFromAddress(locationText);
      if (!mounted) return;
      setState(() {
        _jobLatLng = locations.isNotEmpty
            ? LatLng(locations.first.latitude, locations.first.longitude)
            : const LatLng(48.8566, 2.3522);
        _isGeocoding = false;
      });
    } catch (e) {
      print("Geocoding error: $e");
      if (!mounted) return;
      setState(() {
        _jobLatLng = const LatLng(48.8566, 2.3522);
        _isGeocoding = false;
      });
    }
  }

  Widget _buildTabContent(List<String> responsibilities, double height) {
    switch (selectedTab) {
      case 1:
        return _buildSummaryTab(responsibilities, height);
      case 2:
        return _buildAboutTab();
      case 3:
        return _buildActivityTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSummaryTab(List<String> responsibilities, double height) {
    final shortDesc = (widget.job['short_description'] as String?)?.trim();
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Courte description',
                style: TextStyle(
                    color: white, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpanded
                      ? (widget.job["short_description"] ?? "")
                      : ((widget.job["short_description"] ?? "")
                              .toString()
                              .split(' ')
                              .take(30)
                              .join(' ') +
                          '...'),
                  style: const TextStyle(
                      color: white_gray,
                      fontWeight: FontWeight.w400,
                      fontSize: 16),
                ),
                GestureDetector(
                  onTap: () => setState(() => isExpanded = !isExpanded),
                  child: Text(isExpanded ? 'Réduire' : 'Voir plus',
                      style: const TextStyle(
                          color: blue,
                          fontWeight: FontWeight.w500,
                          fontSize: 16)),
                ),
                if (responsibilities.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  const Text('Responsabilités',
                      style: TextStyle(
                          color: white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...List.generate(
                    (showAll
                        ? responsibilities.length
                        : (responsibilities.length >= 3
                            ? 3
                            : responsibilities.length)),
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Icon(Icons.circle, color: blue, size: 8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              responsibilities[index],
                              style: const TextStyle(
                                  color: white_gray,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (responsibilities.length > 3)
                    GestureDetector(
                      onTap: () => setState(() => showAll = !showAll),
                      child: Text(showAll ? 'Voir moins' : 'Voir plus',
                          style: const TextStyle(
                              color: blue,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                    ),
                ],
                const SizedBox(height: 30),
                const Text('Lieu du poste',
                    style: TextStyle(
                        color: white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _expandedMap = !_expandedMap),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: _expandedMap ? 350 : 180,
                      width: double.infinity,
                      child: AbsorbPointer(
                        absorbing: !_expandedMap,
                        child: Listener(
                          onPointerDown: (_) =>
                              setState(() => _disableScroll = true),
                          onPointerUp: (_) =>
                              setState(() => _disableScroll = false),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target:
                                  _jobLatLng ?? const LatLng(48.8566, 2.3522),
                              zoom: 12,
                            ),
                            onMapCreated: (c) {
                              if (!_mapController.isCompleted)
                                _mapController.complete(c);
                            },
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            markers: _jobLatLng != null
                                ? {
                                    Marker(
                                      markerId: const MarkerId("jobLocation"),
                                      position: _jobLatLng!,
                                      infoWindow: InfoWindow(
                                        title: widget.job["company_name"] ??
                                            "Company",
                                        snippet: widget.job["location"] ?? "",
                                      ),
                                    ),
                                  }
                                : {},
                          ),
                        ),
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

  Widget _buildAboutTab() {
    final shortDesc = (widget.job['description'] as String?)?.trim();
    final salaryText = _formatSalary(widget.job['salary']);
    final employmentText =
        _mapEmploymentType(widget.job['employment_type'] as String?);
    final contractText =
        _mapContractType(widget.job['contract_type'] as String?);
    return Container(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description Détaillée',
                style: TextStyle(
                    color: white, fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),

            if (shortDesc != null && shortDesc.isNotEmpty)
              Text(
                isExpanded
                    ? (widget.job["description"] ?? "")
                    : ((widget.job["description"] ?? "")
                            .toString()
                            .split(' ')
                            .take(25)
                            .join(' ') +
                        '...'),
                style: const TextStyle(
                    color: white_gray,
                    fontWeight: FontWeight.w400,
                    fontSize: 16),
              ),
            GestureDetector(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Text(isExpanded ? 'Réduire' : 'Voir plus',
                  style: const TextStyle(
                      color: blue, fontWeight: FontWeight.w500, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 14),
            //   child: Wrap(
            //     spacing: 10,
            //     runSpacing: 10,
            //     alignment: WrapAlignment.center,
            //     children: [
            //       InfoPill(
            //           icon: Icons.payments_rounded,
            //           label: 'Salaire',
            //           value: salaryText),
            //       InfoPill(
            //           icon: Icons.work_history_rounded,
            //           label: 'Type',
            //           value: employmentText),
            //       InfoPill(
            //           icon: Icons.description_rounded,
            //           label: 'Contrat',
            //           value: contractText),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    final rawSalary = widget.job['salary'];
    final periodText = salaryPeriodTextSmart(rawSalary);
    final salaryText = _formatSalary(rawSalary);
    final employmentText =
        _mapEmploymentType(widget.job['employment_type'] as String?);
    final contractText =
        _mapContractType(widget.job['contract_type'] as String?);
    // attempts a guess if unknown

    return Container(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activité',
              style: TextStyle(
                  color: white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: blendedBlue.withOpacity(0.18),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: blendedBlue.withOpacity(0.45)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Lottie.asset(coin, fit: BoxFit.contain),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Salaire ',
                            style: TextStyle(
                                color: white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('le salaire attendu est de $salaryText',
                            style: TextStyle(color: white_gray, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Text(periodText,
                        style: TextStyle(
                            color: white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            // CONTRAT — bigger Lottie
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80, // was 64
                    height: 80,
                    decoration: BoxDecoration(
                      color: blendedBlue.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: blendedBlue.withOpacity(0.45)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                          4), // tighter padding for larger render
                      child: ClipOval(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Lottie.asset(
                            contract, // e.g. 'assets/lottie/contract.json'
                            width: 76,
                            height: 76, // make sure it fills the circle nicely
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Contrat',
                            style: TextStyle(
                                color: white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(contractText,
                            style: const TextStyle(
                                color: white_gray, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Text(
                      (widget.job['contract_type'] ?? '')
                          .toString()
                          .toUpperCase(),
                      style: const TextStyle(
                          color: white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            // TYPE — slightly larger, but less than contract
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80, // was 64
                    height: 80,
                    decoration: BoxDecoration(
                      color: blendedBlue.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: blendedBlue.withOpacity(0.45)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Lottie.asset(
                            type, // e.g. 'assets/lottie/agenda.json'
                            width: 62, height: 62,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Type',
                            style: TextStyle(
                                color: white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(employmentText,
                            style: const TextStyle(
                                color: white_gray, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Text(
                      employmentText,
                      style: const TextStyle(
                          color: white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _userId;
  final Completer<GoogleMapController> _mapController = Completer();
  bool _expandedMap = false; // for single map on this page
  bool isLoading = true;
  Map<int, bool> _expandedMaps = {};
  void _fetchJobs() async {
    try {
      final fetchedJobs = await ApiService.fetchAllJobs();
      if (!mounted) return;
      setState(() {
        jobs = fetchedJobs;
        isLoading = false;
      });

      for (int i = 0; i < fetchedJobs.length; i++) {
        _expandedMaps[i] = false;
      }
    } catch (e) {
      print("❌ Failed to fetch jobs: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    if (_userId != null) {
      final saved = await ApiService.fetchSavedJobIds(_userId!);
      setState(() => isSaved = saved.contains(widget.job['job_id'].toString()));
    }
  }

  final ScrollController _pageScroll = ScrollController();
  double _lastOffset = 0.0;

  int _pushDir = 1;

  void _setTab(int i) {
    if (i == selectedTab) return;
    _pushDir = i > selectedTab ? 1 : -1;

    _lastOffset = _pageScroll.hasClients ? _pageScroll.offset : 0.0;
    setState(() => selectedTab = i);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageScroll.hasClients) {
        final max = _pageScroll.position.maxScrollExtent;
        _pageScroll.jumpTo(_lastOffset.clamp(0.0, max));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    requestLocationPermission();
    _resolveLocation();
    _initSavedState();
  }

  Future<void> _toggleSave() async {
    if (_userId == null) return;
    final jobId = widget.job['job_id'].toString();
    try {
      final resp = isSaved
          ? await ApiService.removeSaveJob(userId: _userId!, jobId: jobId)
          : await ApiService.saveJob(userId: _userId!, jobId: jobId);
      if (resp.statusCode == 200) {
        setState(() => isSaved = !isSaved);
      } else {
        print('❌ Failed: ${resp.statusCode}');
      }
    } catch (e) {
      print('❌ Error toggling save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print("📍 Resolved “${widget.job["location"]}” to $_jobLatLng");
    final List<String> responsibilities = (widget.job["requirements"] is List)
        ? List<String>.from(widget.job["requirements"])
        : [];

    final height = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: black,
      body: NotificationListener<ScrollNotification>(
        onNotification: (_) => false,
        child: SingleChildScrollView(
          key: const PageStorageKey('job_infos_scroll'),
          controller: _pageScroll,
          primary: false,
          physics: _disableScroll
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 20),
                    decoration: const BoxDecoration(
                        color: blendedBlue,
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(25),
                            bottomRight: Radius.circular(25))),
                    child: Column(
                      children: [
                        SizedBox(height: height * 0.1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 15),
                            Padding(
                              padding: EdgeInsets.only(top: 15),
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: white,
                                  size: 28,
                                ),
                              ),
                            ),
                            const Expanded(child: SizedBox(width: 1)),
                            Padding(
                              padding: const EdgeInsets.only(top: 20, left: 23),
                              child: Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                    color: white,
                                    borderRadius: BorderRadius.circular(100)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
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
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: CompanyLogo(
                                        widget.job['company_logo_url'] ?? ''),
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(child: SizedBox(width: 1)),
                            GestureDetector(
                              onTap: saveJob,
                              child: Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: IconButton(
                                    onPressed: _toggleSave,
                                    icon: Icon(
                                      isSaved
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      color: white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          ],
                        ),
                        SizedBox(height: height * 0.04),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Center(
                            child: Text(
                              widget.job["title"] ?? "Inconnu",
                              style: const TextStyle(
                                color: white,
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.job["company_name"] ?? "France Travail",
                          style: const TextStyle(
                            color: white,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: white, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.job["location"]
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ==
                                            true
                                        ? widget.job["location"]!
                                        : "Ile-de-France",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: height * 0.05),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: (widget.job["category_chip"]
                                        as List<dynamic>? ??
                                    [])
                                .map((chip) => JobTag(chip.toString()))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: height * 0.075),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _setTab(1),
                          child: Text(
                            'Résumé',
                            style: TextStyle(
                              color: selectedTab == 1 ? blue : white_gray,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _setTab(2),
                          child: Text(
                            'Description',
                            style: TextStyle(
                              color: selectedTab == 2 ? blue : white_gray,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _setTab(3),
                          child: Text(
                            'À propos',
                            style: TextStyle(
                              color: selectedTab == 3 ? blue : white_gray,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Updated Progress Bar Container
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      children: [
                        for (int i = 1; i <= 3; i++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 4,
                              decoration: BoxDecoration(
                                color: selectedTab == i ? blue : white_gray,
                                borderRadius: BorderRadius.horizontal(
                                  left: i == 1
                                      ? const Radius.circular(50)
                                      : Radius.zero,
                                  right: i == 3
                                      ? const Radius.circular(50)
                                      : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  PushSwitcher(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOutCubic,
                    direction: _pushDir,
                    child: KeyedSubtree(
                      key: ValueKey<int>(selectedTab),
                      child: _buildTabContent(responsibilities, height),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ScrollController? _scrollController;

  void _disableParentScroll() {
    _scrollController?.position.isScrollingNotifier.value = false;
  }

  void _enableParentScroll() {
    _scrollController?.position.isScrollingNotifier.value = true;
  }
}

class JobTag extends StatelessWidget {
  final String text;

  const JobTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(54, 255, 255, 255),
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Text(
        text,
        style: const TextStyle(color: white),
      ),
    );
  }
}

class PushSwitcher extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final int direction; // 1 = left, -1 = right
  const PushSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 50),
    this.curve = Curves.easeInOutCubic,
    this.direction = 1,
  });

  @override
  State<PushSwitcher> createState() => _PushSwitcherState();
}

class _PushSwitcherState extends State<PushSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: widget.curve);
  Widget? _prevChild;
  Widget? _currChild;
  int _dir = 1;

  @override
  void initState() {
    super.initState();
    _currChild = widget.child;
    _dir = widget.direction;
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(PushSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Keep duration/curve in sync
    if (widget.duration != oldWidget.duration) {
      _ctrl.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _t = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    }

    final newKey = widget.child.key;
    final currKey = _currChild?.key;

    if (newKey != currKey) {
      // Key changed (e.g., tab changed) -> animate push
      _prevChild = _currChild;
      _currChild = widget.child;
      _dir = widget.direction;
      _t = CurvedAnimation(parent: _ctrl, curve: widget.curve);
      _ctrl
          .forward(from: 0)
          .whenComplete(() => setState(() => _prevChild = null));
    } else {
      // Same key (e.g., Voir plus / Réduire toggled) -> just refresh content, no animation
      _currChild = widget.child;
      _dir = widget.direction; // keep direction up to date
      // No setState needed: we're already in an update and build will use the new _currChild
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, __) {
          final v = _t.value;
          final prevX = _dir == 1 ? -v : v;
          final currX = _dir == 1 ? 1 - v : -1 + v;
          return Stack(
            children: [
              if (_prevChild != null)
                FractionalTranslation(
                  translation: Offset(prevX, 0),
                  child: Material(color: Colors.transparent, child: _prevChild),
                ),
              if (_currChild != null)
                FractionalTranslation(
                  translation: Offset(currX, 0),
                  child: Material(color: Colors.transparent, child: _currChild),
                ),
            ],
          );
        },
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoPill(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: white),
          const SizedBox(width: 8),
          Text('$label: ',
              style:
                  const TextStyle(color: white, fontWeight: FontWeight.w600)),
          Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: white_gray))),
        ],
      ),
    );
  }
}
