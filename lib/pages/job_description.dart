// ignore_for_file: unused_field

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/services/api_service.dart';
import 'package:geocoding/geocoding.dart';

class JobInformations extends StatefulWidget {
  final Map<String, dynamic> job;
  JobInformations({super.key, required this.job});

  @override
  State<JobInformations> createState() => _JobInformationsState();
}

class _JobInformationsState extends State<JobInformations> {
  int selectedTab = 1;
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

  @override
  Widget build(BuildContext context) {
    final List<String> responsibilities = (widget.job["requirements"] is List)
        ? List<String>.from(widget.job["requirements"])
        : [];

    final height = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: black,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _disableScroll,
        child: SingleChildScrollView(
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    widget.job["company_logo_url"] ?? '',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image_not_supported),
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(child: SizedBox(width: 1)),
                            GestureDetector(
                              onTap: saveJob,
                              child: Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      isSaved = !isSaved;
                                    });
                                  },
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
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          ],
                        ),
                        SizedBox(height: height * 0.04),
                        Center(
                          child: Text(
                            widget.job["title"] ?? "Unknown",
                            style: const TextStyle(
                              color: white,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.job["company_name"] ?? "Unknown",
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
                          onTap: () => setState(() => selectedTab = 1),
                          child: Text(
                            'Summary',
                            style: TextStyle(
                              color: selectedTab == 1 ? blue : white_gray,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => selectedTab = 2),
                          child: Text(
                            'About',
                            style: TextStyle(
                              color: selectedTab == 2 ? blue : white_gray,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => selectedTab = 3),
                          child: Text(
                            'Activity',
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

                  const SizedBox(height: 40),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(width: 20),
                      Text(
                        'Description',
                        style: TextStyle(
                            color: white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Updated description with Read more functionality
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpanded
                              ? (widget.job["description"] ?? "")
                              : ((widget.job["description"] ?? "")
                                      .toString()
                                      .split(' ')
                                      .take(30)
                                      .join(' ') +
                                  '...'),
                          style: const TextStyle(
                            color: white_gray,
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isExpanded = !isExpanded;
                            });
                          },
                          child: Text(
                            isExpanded ? 'Read less' : 'Read more',
                            style: const TextStyle(
                              color: blue,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (responsibilities.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          const Text(
                            'Responsibilities',
                            style: TextStyle(
                              color: white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                                    child: Icon(Icons.circle,
                                        color: blue, size: 8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      responsibilities[index],
                                      style: const TextStyle(
                                        color: white_gray,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (responsibilities.length > 3)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  showAll = !showAll;
                                });
                              },
                              child: Text(
                                showAll ? 'See less' : 'Read more',
                                style: const TextStyle(
                                  color: blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 30),
                        const Text(
                          'Job Location',
                          style: TextStyle(
                            color: white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _expandedMap = !_expandedMap),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: _expandedMap ? 350 : 180,
                              width: double.infinity,
                              child: AbsorbPointer(
                                absorbing:
                                    !_expandedMap, // Only allow gestures when expanded
                                child: Listener(
                                  onPointerDown: (_) =>
                                      setState(() => _disableScroll = true),
                                  onPointerUp: (_) =>
                                      setState(() => _disableScroll = false),
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: _jobLatLng ??
                                          const LatLng(48.8566, 2.3522),
                                      zoom: 12,
                                    ),
                                    onMapCreated:
                                        (GoogleMapController controller) {
                                      if (!_mapController.isCompleted) {
                                        _mapController.complete(controller);
                                      }
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
                                              markerId:
                                                  const MarkerId("jobLocation"),
                                              position: _jobLatLng!,
                                              infoWindow: InfoWindow(
                                                title: widget
                                                        .job["company_name"] ??
                                                    "Company",
                                                snippet:
                                                    widget.job["location"] ??
                                                        "",
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
