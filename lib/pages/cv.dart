// ignore_for_file: dead_code, avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/themes.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:swipply/env.dart';

class InterestsSection extends StatefulWidget {
  final List<String> interests;

  const InterestsSection({super.key, required this.interests});

  @override
  State<InterestsSection> createState() => _InterestsSectionState();
}

class _InterestsSectionState extends State<InterestsSection> {
  bool showAll = false;

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditInterestsSheet(
        interests: widget.interests,
        onSave: (updated) {
          setState(() {
            widget.interests.addAll(updated);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: blue_gray,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Interests',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openEditSheet,
                child: const Icon(Icons.edit, color: white_gray, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // 🧠 Display bullet points
          ...List.generate(
            showAll
                ? widget.interests.length
                : (widget.interests.length > 3 ? 3 : widget.interests.length),
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, color: blue, size: 6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.interests[index],
                      style: const TextStyle(
                        color: white_gray,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔁 Read More / Less
          if (widget.interests.length > 3)
            GestureDetector(
              onTap: () => setState(() => showAll = !showAll),
              child: Text(
                showAll ? 'Read less' : 'Read more',
                style: const TextStyle(
                  color: blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum UploadStatus {
  idle,
  uploading,
  parsing,
  success,
  error,
}

late Set<String> selectedLanguages;

class CV extends StatefulWidget {
  const CV({super.key});

  @override
  State<CV> createState() => _CVState();
}

class _CVState extends State<CV> with TickerProviderStateMixin {
  TextEditingController? resumeController;
  List<String> educations = [];
  String? phone;
  String? address;

  String? userId;
  late List<String> languages;
  String _uploadedFileName = 'Upload a Doc/Docx/PDF';
  late AnimationController _checkmarkController;

  void fetchUserId() async {
    final id = await getUserId();
    setState(() {
      userId = id;
    });
    print("🟢 Logged-in user_id: $userId");
  }

  String startDateText = 'Immediately';
  List<String> interests = [];
  void showSuccessCheckPopup() {
    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Center(
          child: Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _checkmarkController,
              builder: (_, __) => CustomPaint(
                painter: CheckMarkPainter(_checkmarkController),
              ),
            ),
          ),
        );
      },
    );

    // Start the animation after dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkmarkController.forward(from: 0);
    });

    // Close the dialog after 3 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  List<Map<String, dynamic>> skills = [];
  Future<void> saveCV() async {
    final userId = await getUserId();
    final token = await getAuthToken();

    if (userId == null || token == null) {
      showUploadPopup(context, errorMessage: "Missing user ID or token");
      return;
    }

    showUploadPopup(context); // Show loading popup

    final safePhone = phone?.trim();
    final safeAddress = address?.trim();

    final data = {
      'email': userEmail,
      if (safePhone != null && safePhone.isNotEmpty) 'phone': safePhone,
      if (safeAddress != null && safeAddress.isNotEmpty) 'address': safeAddress,
      'resume': resumeController?.text.trim(),
      'experience': experiences,
      'education': educations,
      'availability': startDateText,
      'weeklyAvailability': weeklyAvailability,
      'interests': selectedInterests,
      'softSkills': softSkills.toList(),
      'skillsAndProficiency': skills,
      'languages': selectedLanguages.toList(),
      'certificates': certificates,
    };

    final body = {
      'user_id': userId,
      'data': data,
    };

    try {
      final response = await http.post(
        Uri.parse("$BASE_URL_AUTH/api/save-cv"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        showSuccessCheckPopup(); // ✅ Success animation
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
      } else {
        showUploadPopup(context, errorMessage: "Error saving CV");
      }
    } catch (e) {
      Navigator.of(context).pop();
      showUploadPopup(context, errorMessage: "Error: ${e.toString()}");
    }
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  List<String> softSkills = [];

  UploadStatus _status = UploadStatus.idle;
  double _uploadProgress = 0;
  Map<String, dynamic>? parsedCVData;
  bool _showLoadingPopup = false;
  List<Map<String, dynamic>> certificates = [];
  String userEmail = '';
  String userPhone = '';

  String? selectedFileName = 'Upload a Doc/Docx/PDF';
  Map<String, List<String>> weeklyAvailability = {};
  List<String> selectedInterests = [];
  void showUploadPopup(BuildContext context, {String? errorMessage}) {
    final bool isError = errorMessage != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: isError ? 300 : 100,
              height: 100,
              decoration: BoxDecoration(
                color: blue_gray,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(horizontal: isError ? 16 : 0),
              child: Row(
                mainAxisAlignment: isError
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: const LoadingBars(),
                  ),
                  if (isError) const SizedBox(width: 12),
                  if (isError)
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

//////////////////////////////
  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _status = UploadStatus.uploading;
        _uploadProgress = 0;
      });

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$BASE_URL_AUTH/api/parse-cv'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('cv', file.path, filename: fileName),
      );

      // Show loading popup
      showUploadPopup(
        context,
      );

      try {
        final streamedResponse = await request.send();

        // Simulate progress manually
        const fakeTotalSteps = 30;
        for (int i = 0; i < fakeTotalSteps; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          setState(() {
            _uploadProgress = (i + 1) / fakeTotalSteps;
          });
        }

        final response = await http.Response.fromStream(streamedResponse);
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData.containsKey('parsed')) {
          final parsedData = responseData['parsed'];

          setState(() {
            selectedLanguages = Set<String>.from(parsedData['languages'] ?? []);
            resumeController?.text = parsedData['resumeSummary'] ?? '';
            _uploadedFileName = result.files.single.name;
            parsedExperiences =
                (parsedData['experiences'] as List<dynamic>? ?? [])
                    .map((e) => Map<String, String>.from(e as Map))
                    .toList();

            experiences =
                parsedExperiences.map((map) => map.values.join(" – ")).toList();

            educations = (parsedData['education'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e).values.join(" – "))
                .toList();
            certificates = (parsedData['certificates'] as List<dynamic>? ?? [])
                .map((e) => {
                      'title': e['title']?.toString() ?? '',
                      'issuer': e['issuer']?.toString() ?? '',
                      'date': e['date']?.toString() ?? '',
                      'verified': e['verified'].toString() == 'true' ||
                          e['verified'] == true,
                    })
                .toList();

            skills =
                (parsedData['skillsAndProficiency'] as List<dynamic>? ?? [])
                    .map((e) {
              final map = Map<String, dynamic>.from(e);
              return {
                "name": map['skill'] ?? '',
                "level": (map['proficiency'] ?? 0) / 100,
              };
            }).toList();

            selectedInterests =
                List<String>.from(parsedData['interests'] ?? []);
            softSkills = List<String>.from(parsedData['softSkills'] ?? []);
            parsedCVData = parsedData;
            _status = UploadStatus.success;
          });

          Navigator.of(context).pop();
          showSuccessCheckPopup(); // Close popup
        } else {
          setState(() {
            _status = UploadStatus.error;
          });
          Navigator.of(context).pop(); // Close loading
          showUploadPopup(
            context,
            errorMessage: "Error parsing CV",
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _status = UploadStatus.error;
        });
        Navigator.of(context).pop(); // Close loading
        showUploadPopup(
          context,
          errorMessage: "Error parsing CV. Please try again.",
        );
        Navigator.of(context).pop();
      }
    }
  }

  List<Map<String, String>> parsedExperiences = [];

  bool _showCheckPopup = false;
  bool showAll = false;
  List<String> experiences = [];
  void openCertificateFile(String? path) async {
    if (path == null) return;
    try {
      await OpenFile.open(path);
    } catch (e) {
      print("Error opening file: $e");
    }
  }

  void _openCertificatesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCertificatesSheet(
        initialCertificates: certificates,
        onSave: (updated) => setState(() => certificates = updated),
      ),
    );
  }

  String formatAvailabilitySummary(Map<String, List<String>> availability) {
    final List<String> parts = [];

    availability.forEach((day, slots) {
      if (slots.isNotEmpty) {
        parts.add('$day: ${slots.join(", ")}');
      }
    });

    return parts.isEmpty ? 'No availability selected' : parts.join("  •  ");
  }

  @override
  void initState() {
    super.initState();
    selectedLanguages = {};
    resumeController = TextEditingController();
    fetchUserId();
    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _checkmarkController.reset(); // reset for reuse
        }
      });
// If it's a Set<String>
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    print('🧠 experiences: ${parsedCVData?['experiences']}');
    print('🧠 softSkills: ${parsedCVData?['softSkills']}');
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: black,
      body: Stack(
        children: [
          if (_showLoadingPopup)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: const Center(child: LoadingBars()),
              ),
            ),
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.05,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          decoration: BoxDecoration(
                              border: Border.all(
                                color: black_gray,
                              ),
                              borderRadius: BorderRadius.circular(100)),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back,
                              color: white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      const Expanded(
                          child: SizedBox(
                        width: 1,
                      )),
                      const Padding(
                        padding: EdgeInsets.only(right: 37),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                              color: white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Expanded(
                          child: SizedBox(
                        width: 1,
                      )),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 15, right: 15),
                  child: Row(
                    children: [
                      Text(
                        'Resume or CV',
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            color: white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                      Expanded(
                          child: SizedBox(
                        width: 1,
                      ))
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: Center(
                    child: CustomPaint(
                      painter: DashedBorderPainter(),
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20)),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            SizedBox(
                              height: height * 0.04,
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                  left:
                                      MediaQuery.of(context).size.width * 0.14,
                                  right:
                                      MediaQuery.of(context).size.width * 0.14),
                              child: const Text(
                                "Upload your CV or resume and use it when you apply for jobs",
                                style: TextStyle(
                                    color: white_gray,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(
                              height: 30,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: blue_gray,
                              ),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: height * 0.03,
                                  bottom: height * 0.03,
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(child: SizedBox(width: 1)),
                                    Expanded(
                                        flex: 8,
                                        child: SizedBox(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.6,
                                          child: WaveWipeTextSwitcher(
                                            key: ValueKey(_uploadedFileName),
                                            text: _uploadedFileName,
                                          ),
                                        )),
                                    const Expanded(child: SizedBox(width: 1)),
                                  ],
                                ),
                              ),
                            ),
                            if (_status == UploadStatus.uploading ||
                                _status == UploadStatus.parsing)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Container(
                                  width: width * 0.7,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: blue,
                                  ),
                                  child: Stack(
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: _uploadProgress,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          "${(_uploadProgress * 100).toInt()}%",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            else if (_status == UploadStatus.error)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red),
                                    const SizedBox(width: 6),
                                    const Text(
                                      "Error while uploading",
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _status = UploadStatus.uploading;
                                          _uploadProgress = 0;
                                        });
                                        pickFile(); // retry
                                      },
                                      child: const Icon(Icons.refresh,
                                          color: Colors.white),
                                    )
                                  ],
                                ),
                              ),
                            const SizedBox(
                              height: 30,
                            ),
                            GestureDetector(
                              onTap: pickFile,
                              child: Container(
                                width: width * 0.55,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: blue),
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 15, bottom: 15),
                                  child: Row(
                                    children: [
                                      Expanded(child: SizedBox(width: 1)),
                                      Text(
                                        'Upload',
                                        style: TextStyle(
                                            color: white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      Expanded(child: SizedBox(width: 1)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: height * 0.05,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 15),
                      child: Text(
                        'Languages I Know',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: white),
                      ),
                    ),
                    Expanded(
                        child: SizedBox(
                      width: 1,
                    ))
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                GestureDetector(
                  onTap: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const _LanguageDetailsSheet(),
                    );
                    setState(() {}); // 👈 Refresh to show new language list
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        color: blue_gray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 15, bottom: 15),
                        child: Row(
                          children: [
                            const SizedBox(width: 20),
                            const Icon(Icons.language, color: white_gray),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                selectedLanguages.isEmpty
                                    ? 'No language selected'
                                    : selectedLanguages.join(', '),
                                style: const TextStyle(
                                  color: white,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 25,
                              color: white_gray,
                            ),
                            const SizedBox(width: 15),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 15),
                      child: Text(
                        'Resume',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: white),
                      ),
                    ),
                    Expanded(
                        child: SizedBox(
                      width: 1,
                    ))
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                if (resumeController != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    child: ExpandingResumeField(controller: resumeController!),
                  ),
                const SizedBox(
                  height: 20,
                ),
                const Row(
                  children: [
                    Expanded(
                        child: SizedBox(
                      width: 1,
                    ))
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: blue_gray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🧠 Header
                        Row(
                          children: [
                            const Text(
                              'Experience',
                              style: TextStyle(
                                color: white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                // TODO: Open bottom sheet or editable modal
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => EditExperienceSheet(
                                    experiences: experiences,
                                    onSave: (updatedList) {
                                      setState(() {
                                        experiences = updatedList;
                                      });
                                    },
                                  ),
                                );
                              },
                              child: const Icon(Icons.edit,
                                  color: white_gray, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // 📋 List of experiences
                        ...List.generate(
                          showAll
                              ? experiences.length
                              : (experiences.length > 3
                                  ? 3
                                  : experiences.length),
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child:
                                      Icon(Icons.circle, color: blue, size: 6),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    experiences[index],
                                    style: const TextStyle(
                                      color: white_gray,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 🔽 Read More
                        // 🔽 Read More / 🔼 Read Less toggle
                        if (experiences.length > 3)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showAll = !showAll;
                              });
                            },
                            child: Text(
                              showAll ? 'Read less' : 'Read more',
                              style: const TextStyle(
                                color: blue,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                EducationSection(
                  educations: educations,
                ),
                const SizedBox(
                  height: 15,
                ),
                AvailabilitySection(),
                const SizedBox(
                  height: 15,
                ),
                WeeklyAvailabilitySection(
                  initialAvailability: weeklyAvailability,
                  onChanged: (updated) {
                    setState(() {
                      weeklyAvailability = updated;
                    });
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🧠 Section Title
                      InterestsSection(
                        interests: selectedInterests,
                      ),

                      const SizedBox(height: 25),
                      GestureDetector(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => EditSoftSkillsSheet(
                              initialSoftSkills: softSkills,
                              onSave: (updated) {
                                setState(() {
                                  softSkills = updated;
                                });
                              },
                            ),
                          );

                          setState(() {}); // refresh UI with updated softSkills
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: blue_gray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.extension, color: white_gray),
                              SizedBox(width: 10),
                              Text(
                                'Select Soft Skills',
                                style: TextStyle(color: white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: softSkills
                            .map((skill) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: black_gray,
                                    border: Border.all(color: white_gray),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    skill,
                                    style: const TextStyle(
                                      color: white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 15),
                      SkillsSection(skills: skills),
                      ContactInfoSection(
                        phoneNumber: phone ?? '',
                        address: address ?? '',
                        onSave: (updatedPhone, updatedAddress) {
                          setState(() {
                            phone = updatedPhone;
                            address = updatedAddress;
                          });
                        },
                      ),

                      const SizedBox(height: 15),
                      Container(
                        decoration: BoxDecoration(
                          color: blue_gray,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Certificates',
                                  style: TextStyle(
                                    color: white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _openCertificatesSheet,
                                  child: const Icon(Icons.edit,
                                      color: white_gray, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            if (certificates.isEmpty)
                              const Text(
                                'No certificates added yet.',
                                style: TextStyle(color: white_gray),
                              )
                            else
                              Column(
                                children: certificates.map((cert) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: black_gray,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: white_gray.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.workspace_premium,
                                                size: 20, color: blue),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cert['title'] ?? 'Untitled',
                                                style: const TextStyle(
                                                  color: white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            if (cert['verified'] ==
                                                'true') // Notice it's a String comparison
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    top: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                  gradient:
                                                      const LinearGradient(
                                                    colors: [
                                                      Colors.greenAccent,
                                                      Colors.green
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.green
                                                          .withOpacity(0.4),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.verified,
                                                        size: 14, color: black),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Verified',
                                                      style: TextStyle(
                                                        color: black,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          cert['issuer'] ?? 'Unknown issuer',
                                          style: const TextStyle(
                                              color: white_gray, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cert['date'] ?? 'No date',
                                          style: const TextStyle(
                                              color: white_gray, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _openCertificatesSheet,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: black,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: white_gray),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, color: white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Add Certificate',
                                        style: TextStyle(
                                          color: white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(
                  height: 100,
                )
              ],
            ),
          ),
          if (_showCheckPopup)
            Center(
              child: AnimatedOpacity(
                opacity: _showCheckPopup ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: const AnimatedCheckMark(size: 60),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(left: 30, right: 30, bottom: 20),
              child: GestureDetector(
                onTap: () async {
                  await saveCV();
                },
                child: Container(
                  width: width,
                  height: 60,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: const Center(
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class CertificatesSection extends StatelessWidget {
  final List<Map<String, dynamic>> certificates;
  final Function(List<Map<String, dynamic>>) onUpdate;

  const CertificatesSection({
    super.key,
    required this.certificates,
    required this.onUpdate,
  });

  void _openEditCertificates(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCertificatesSheet(
        initialCertificates: certificates,
        onSave: onUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Certificates',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openEditCertificates(context),
                  child: const Icon(Icons.edit, color: white_gray, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (certificates.isEmpty)
              const Text(
                'No certificates added yet.',
                style: TextStyle(color: white_gray),
              )
            else
              Column(
                children: certificates.map((cert) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: black_gray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: white_gray.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium,
                                size: 20, color: blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cert['title'] ?? 'Untitled',
                                style: const TextStyle(
                                  color: white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (cert['verified'] == true ||
                                cert['verified'] == 'true')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  gradient: const LinearGradient(
                                    colors: [Colors.greenAccent, Colors.green],
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified,
                                        size: 14, color: black),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        color: black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cert['issuer'] ?? 'Unknown issuer',
                          style:
                              const TextStyle(color: white_gray, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cert['date'] ?? 'No date',
                          style:
                              const TextStyle(color: white_gray, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class EditCertificatesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialCertificates;
  final Function(List<Map<String, String>>) onSave;

  const EditCertificatesSheet({
    super.key,
    required this.initialCertificates,
    required this.onSave,
  });

  @override
  State<EditCertificatesSheet> createState() => _EditCertificatesSheetState();
}

class _EditCertificatesSheetState extends State<EditCertificatesSheet> {
  final List<Map<String, String>> certificates = [];
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _issuerController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  PlatformFile? selectedFile;
  bool verified = false;

  @override
  void initState() {
    super.initState();
    for (var cert in widget.initialCertificates) {
      certificates.add(
          cert.map((key, value) => MapEntry(key, value?.toString() ?? '')));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg'],
    );

    if (result != null && result.files.single.name.isNotEmpty) {
      setState(() => selectedFile = result.files.single);
    }
  }

  void _addCertificate() {
    if (_titleController.text.trim().isEmpty ||
        _issuerController.text.trim().isEmpty) return;

    final newCert = {
      'title': _titleController.text.trim(),
      'issuer': _issuerController.text.trim(),
      'date': _dateController.text.trim(),
      'tag': _tagController.text.trim(),
      'file': selectedFile?.name ?? '',
      'verified': verified.toString(),
    };

    setState(() {
      certificates.add(newCert);
      _titleController.clear();
      _issuerController.clear();
      _dateController.clear();
      _tagController.clear();
      verified = false;
      selectedFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: _scrollController,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 6,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add a New Certificate',
                style: TextStyle(
                    color: white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              _buildTextField(_titleController, 'Certificate Title'),
              const SizedBox(height: 12),
              _buildTextField(_issuerController, 'Issuer (e.g. Coursera)'),
              const SizedBox(height: 12),
              _buildTextField(_dateController, 'Date (Optional)', hint: '2024'),
              const SizedBox(height: 12),
              _buildTextField(_tagController, 'Tag (Optional)',
                  hint: 'e.g. UI/UX'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: white_gray),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload_file, color: white),
                      const SizedBox(width: 10),
                      Text(
                        selectedFile != null
                            ? selectedFile!.name
                            : 'Upload PDF/Image',
                        style: const TextStyle(
                            color: white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                activeColor: blue,
                value: verified,
                onChanged: (val) => setState(() => verified = val),
                title: const Text(
                  'Verified Certificate (Coursera, Google etc)',
                  style: TextStyle(color: white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _addCertificate,
                child: const Text('Add Certificate',
                    style: TextStyle(
                        color: white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 25),
              const Text(
                'Certificates Added',
                style: TextStyle(
                    color: white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...certificates.asMap().entries.map((entry) {
                int index = entry.key;
                final cert = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium,
                              color: blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cert['title'] ?? '',
                              style: const TextStyle(
                                color: white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (cert['verified'] == 'true')
                            Container(
                              margin: const EdgeInsets.only(right: 2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified,
                                  color: Colors.greenAccent, size: 18),
                            ),
                          IconButton(
                            splashRadius: 24,
                            tooltip: 'Delete Certificate',
                            onPressed: () =>
                                setState(() => certificates.removeAt(index)),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if ((cert['issuer'] ?? '').isNotEmpty ||
                          (cert['date'] ?? '').isNotEmpty)
                        Text(
                          '${cert['issuer'] ?? ''}${cert['issuer'] != null && cert['date'] != null ? ' • ' : ''}${cert['date'] ?? ''}',
                          style:
                              const TextStyle(color: white_gray, fontSize: 13),
                        ),
                      if ((cert['file'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf,
                                  size: 16, color: white_gray),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cert['file']!,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: white_gray, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  widget.onSave(certificates);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Save All',
                      style: TextStyle(
                          color: black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: white),
      decoration: InputDecoration(
        hintText: hint ?? label,
        hintStyle: const TextStyle(color: white_gray),
        labelText: label,
        labelStyle: const TextStyle(color: white_gray),
        filled: true,
        fillColor: black_gray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class EditSkillsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialSkills;
  final Function(List<Map<String, dynamic>>) onSave;

  const EditSkillsSheet({
    super.key,
    required this.initialSkills,
    required this.onSave,
  });

  @override
  State<EditSkillsSheet> createState() => _EditSkillsSheetState();
}

class _EditSkillsSheetState extends State<EditSkillsSheet> {
  late List<Map<String, dynamic>> tempSkills;
  String input = '';

  @override
  void initState() {
    super.initState();
    tempSkills = List.from(widget.initialSkills);
  }

  void _addSkill() {
    if (input.trim().isEmpty) return;
    setState(() {
      tempSkills.add({"name": input.trim(), "level": 0.5});
      input = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 6,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Your Skills',
                style: TextStyle(
                    color: white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      style: const TextStyle(color: white),
                      decoration: const InputDecoration(
                        hintText: 'New Skill',
                        hintStyle: TextStyle(color: white_gray),
                        filled: true,
                        fillColor: black_gray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setState(() => input = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _addSkill,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Column(
                children: tempSkills.map((skill) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              skill['name'],
                              style: const TextStyle(
                                  color: white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => tempSkills.remove(skill)),
                            icon: const Icon(Icons.delete_outline,
                                color: white_gray),
                          ),
                        ],
                      ),
                      Slider(
                        value: skill['level'],
                        onChanged: (val) =>
                            setState(() => skill['level'] = val),
                        min: 0,
                        max: 1,
                        activeColor: skill['level'] <= 0.33
                            ? Colors.orangeAccent
                            : skill['level'] <= 0.66
                                ? Colors.amber
                                : Colors.tealAccent,
                        inactiveColor: white_gray.withOpacity(0.2),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  widget.onSave(tempSkills);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class GradientProgressBar extends StatelessWidget {
  final double value;

  const GradientProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: black_gray,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.redAccent,
                            Colors.deepOrangeAccent,
                            Colors.orangeAccent,
                            Colors.blueAccent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SkillsSection extends StatefulWidget {
  final List<Map<String, dynamic>> skills;
  const SkillsSection({super.key, required this.skills});
  @override
  State<SkillsSection> createState() => _SkillsSectionState();
}

class _SkillsSectionState extends State<SkillsSection> {
  List<Map<String, dynamic>> get skills => widget.skills;

  void _openEditSkills() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditSkillsSheet(
        initialSkills: skills,
        onSave: (updated) => setState(() => skills
          ..clear()
          ..addAll(updated)),
      ),
    );
  }

  Color _levelToColor(double level) {
    if (level <= 0.33) return Colors.orangeAccent;
    if (level <= 0.66) return Colors.amber;
    return Colors.tealAccent;
  }

  String _levelLabel(double level) {
    if (level <= 0.33) return "Beginner";
    if (level <= 0.66) return "Intermediate";
    return "Expert";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: blue_gray,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🧠 Section Header
          Row(
            children: [
              const Text(
                'Skills & Proficiency',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openEditSkills,
                child: const Icon(Icons.edit, color: white_gray, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Show your real strengths. Let recruiters know what you’re best at!',
            style: TextStyle(color: white_gray, fontSize: 14),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: skills.map((skill) {
              return Container(
                decoration: BoxDecoration(
                  color: _levelToColor(skill['level']),
                  borderRadius: BorderRadius.circular(100),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 16,
                      color: black,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      skill['name'],
                      style: const TextStyle(
                          color: black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 25),

          // 🎯 Level bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Beginner', style: TextStyle(color: white)),
              Text('Intermediate', style: TextStyle(color: white_gray)),
              Text('Expert', style: TextStyle(color: white)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: skills.isNotEmpty
                ? skills
                        .map((e) => e['level'] as double)
                        .reduce((a, b) => a + b) /
                    skills.length
                : 0,
            backgroundColor: black_gray,
            color: Colors.tealAccent,
            minHeight: 10,
            borderRadius: BorderRadius.circular(50),
          ),

          const SizedBox(height: 25),
          GestureDetector(
            onTap: _openEditSkills,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: black,
                border: Border.all(color: white_gray),
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: white),
                    SizedBox(width: 6),
                    Text(
                      'Add Skill',
                      style: TextStyle(
                        color: white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditSoftSkillsSheet extends StatefulWidget {
  final List<String> initialSoftSkills;
  final void Function(List<String>) onSave;

  const EditSoftSkillsSheet({
    super.key,
    required this.initialSoftSkills,
    required this.onSave,
  });

  @override
  State<EditSoftSkillsSheet> createState() => _EditSoftSkillsSheetState();
}

class _EditSoftSkillsSheetState extends State<EditSoftSkillsSheet> {
  late Set<String> selected;

  String searchText = '';

  @override
  void initState() {
    super.initState();
    selected = Set.from(widget.initialSoftSkills);
  }

  void toggleSkill(String skill) {
    setState(() {
      if (selected.contains(skill)) {
        selected.remove(skill);
      } else {
        selected.add(skill);
      }

      softSkills
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allSoftSkills
        .where((s) => s.toLowerCase().contains(searchText.toLowerCase()))
        .toList();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) return;
        widget.onSave(selected.toList()); // Return selected soft skills
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (_, controller) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: blue_gray,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 7,
                    decoration: BoxDecoration(
                      color: white_gray,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Your Soft Skills',
                  style: TextStyle(
                    color: white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                // 🔍 Search input
                Container(
                  decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: white_gray),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          onChanged: (val) => setState(() => searchText = val),
                          style: const TextStyle(color: white),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Search soft skills...',
                            hintStyle: TextStyle(color: white_gray),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: filtered.map((skill) {
                    final isSelected = selected.contains(skill);
                    return GestureDetector(
                      onTap: () => toggleSkill(skill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? blue : black_gray,
                          borderRadius: BorderRadius.circular(100),
                          border:
                              isSelected ? null : Border.all(color: white_gray),
                        ),
                        child: Text(
                          skill,
                          style: TextStyle(
                            color: isSelected ? black : white_gray,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EditStartDateSheet extends StatefulWidget {
  final String initialValue;
  final Function(String) onSave;

  const EditStartDateSheet({
    super.key,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<EditStartDateSheet> createState() => _EditStartDateSheetState();
}

class _EditStartDateSheetState extends State<EditStartDateSheet> {
  bool isImmediate = true;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    isImmediate = widget.initialValue == 'Immediately';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 7,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'When can you start working?',
                style: TextStyle(
                    color: white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                activeColor: blue,
                value: isImmediate,
                onChanged: (val) => setState(() => isImmediate = val),
                title: const Text(
                  'Immediately',
                  style: TextStyle(color: white, fontSize: 16),
                ),
              ),
              if (!isImmediate)
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            primaryColor: blue,
                            colorScheme: ColorScheme.dark(
                              primary: blue,
                              onPrimary: white,
                              surface: black,
                              onSurface: white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 15),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: black_gray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: white_gray),
                        const SizedBox(width: 12),
                        Text(
                          selectedDate != null
                              ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                              : 'Select start date',
                          style: const TextStyle(color: white, fontSize: 16),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 25),
              GestureDetector(
                onTap: () {
                  final output = isImmediate
                      ? 'Immediately'
                      : selectedDate != null
                          ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                          : widget.initialValue;
                  widget.onSave(output);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Center(
                    child: Text(
                      'Save',
                      style: TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

const List<String> allSoftSkills = [
  'Communication', 'Teamwork', 'Adaptability', 'Problem-solving',
  'Critical thinking', 'Time management', 'Work ethic', 'Creativity',
  'Emotional intelligence', 'Leadership', 'Responsibility', 'Decision making',
  'Conflict resolution', 'Flexibility', 'Organization', 'Empathy',
  'Collaboration', 'Stress management', 'Multitasking', 'Self-motivation',
  'Listening', 'Accountability', 'Persuasion', 'Negotiation',
  'Patience', 'Confidence', 'Delegation', 'Initiative', 'Attention to detail',
  'Public speaking', 'Positive attitude', 'Active learning',
  'Strategic thinking',
  'Constructive feedback', 'Giving feedback', 'Coaching', 'Mentoring',
  'Discipline', 'Cultural awareness', 'Resourcefulness', 'Integrity',
  'Goal-setting', 'Self-awareness', 'Curiosity', 'Non-verbal communication',
  'Humility', 'Respectfulness', 'Inclusivity', 'Receptiveness',
  // 🔥 Add more to make it 100+ — this is already premium-tier.
];

class AvailabilitySection extends StatefulWidget {
  const AvailabilitySection({super.key});

  @override
  State<AvailabilitySection> createState() => _AvailabilitySectionState();
}

class _AvailabilitySectionState extends State<AvailabilitySection> {
  String startDateText = 'Immediately';

  void _openEditStartDate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditStartDateSheet(
        initialValue: startDateText,
        onSave: (selected) {
          setState(() {
            startDateText = selected;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Availability',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openEditStartDate,
                  child: const Icon(Icons.edit, color: white_gray, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 15),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15),
                children: [
                  const TextSpan(
                    text: 'Start date: ',
                    style: TextStyle(color: white, fontSize: 17),
                  ),
                  TextSpan(
                    text: startDateText,
                    style: const TextStyle(
                        color: white_gray,
                        fontWeight: FontWeight.w500,
                        fontSize: 17),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// 🧠 WEEKLY AVAILABILITY SHEET (FULL PACKAGE)

class WeeklyAvailabilitySection extends StatefulWidget {
  final Map<String, List<String>> initialAvailability;
  final void Function(Map<String, List<String>>) onChanged;

  const WeeklyAvailabilitySection({
    super.key,
    required this.initialAvailability,
    required this.onChanged,
  });

  @override
  State<WeeklyAvailabilitySection> createState() =>
      _WeeklyAvailabilitySectionState();
}

class _WeeklyAvailabilitySectionState extends State<WeeklyAvailabilitySection> {
  late Map<String, List<String>> availability;

  final List<String> days = [
    'Lundi',
    'Mardi',
    'Mercr',
    'Jeudi',
    'Vendr',
    'Samdi',
    'Diman'
  ];

  @override
  void initState() {
    super.initState();
    availability = Map<String, List<String>>.from(widget.initialAvailability);
    for (var day in days) {
      availability.putIfAbsent(day, () => []);
    }
  }

  void toggle(String day, String slot) {
    setState(() {
      if (availability[day]!.contains(slot)) {
        availability[day]!.remove(slot);
      } else {
        availability[day]!.add(slot);
      }
      widget.onChanged(availability);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Container(
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Section title
            const Text(
              'Weekly Availability',
              style: TextStyle(
                  color: white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...days.map((day) {
              final selected = availability[day] ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(day,
                          style: const TextStyle(color: white, fontSize: 14)),
                    ),
                    ToggleChip(
                      label: 'Morning',
                      selected: selected.contains('Morning'),
                      onTap: () => toggle(day, 'Morning'),
                    ),
                    const SizedBox(width: 10),
                    ToggleChip(
                      label: 'Evening',
                      selected: selected.contains('Evening'),
                      onTap: () => toggle(day, 'Evening'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class EditInterestsSheet extends StatefulWidget {
  final List<String> interests;
  final Function(List<String>) onSave;

  const EditInterestsSheet({
    super.key,
    required this.interests,
    required this.onSave,
  });

  @override
  State<EditInterestsSheet> createState() => _EditInterestsSheetState();
}

class _EditInterestsSheetState extends State<EditInterestsSheet> {
  late List<TextEditingController> controllers;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controllers = widget.interests
        .map((interest) => TextEditingController(text: interest))
        .toList();
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addInterest() {
    setState(() {
      controllers.add(TextEditingController());
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeInterest(int index) {
    setState(() {
      controllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: _scrollController,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 5,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Edit Interests',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              ...List.generate(controllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controllers[index],
                          maxLines: null,
                          style: const TextStyle(color: white),
                          decoration: InputDecoration(
                            hintText: 'Interest ${index + 1}',
                            hintStyle: const TextStyle(color: white_gray),
                            filled: true,
                            fillColor: black_gray,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DeleteIconButton(
                        onPressed: () => _removeInterest(index),
                      ),
                    ],
                  ),
                );
              }),

              // ➕ Add Interest Button
              TextButton.icon(
                onPressed: _addInterest,
                icon: const Icon(Icons.add, color: blue),
                label: const Text(
                  'Add Interest',
                  style: TextStyle(color: blue),
                ),
              ),

              const SizedBox(height: 20),

              // 🔍 Preview
              if (controllers.any((c) => c.text.trim().isNotEmpty)) ...[
                const Text(
                  'Preview:',
                  style: TextStyle(
                      color: white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: controllers
                        .where((c) => c.text.trim().isNotEmpty)
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle,
                                      color: blue, size: 6),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.text.trim(),
                                      style: const TextStyle(
                                        color: white_gray,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // ✅ Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final updated = controllers
                      .map((c) => c.text.trim())
                      .where((text) => text.isNotEmpty)
                      .toList();
                  widget.onSave(updated);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  IconData get icon =>
      label == 'Morning' ? Icons.wb_sunny_rounded : Icons.nightlight_round;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? blue : black_gray,
          borderRadius: BorderRadius.circular(100),
          border: selected ? null : Border.all(color: white_gray),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? black : white_gray, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? black : white_gray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EducationSection extends StatefulWidget {
  final List<String> educations;

  const EducationSection({super.key, required this.educations});

  @override
  State<EducationSection> createState() => _EducationSectionState();
}

class _EducationSectionState extends State<EducationSection> {
  bool showAll = false;

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditEducationSheet(
        educations: widget.educations, // ✅ correct usage

        onSave: (updated) {
          setState(() {
            widget.educations.clear();
            widget.educations.addAll(updated);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎓 Title row
            Row(
              children: [
                const Text(
                  'Education',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openEditSheet,
                  child: const Icon(Icons.edit, color: white_gray, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 📋 Education items
            ...List.generate(
              showAll
                  ? widget.educations.length
                  : (widget.educations.length > 3
                      ? 3
                      : widget.educations.length),
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.school, color: blue, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.educations[index],
                        style: const TextStyle(
                          color: white_gray,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🔁 Read more / less
            if (widget.educations.length > 3)
              GestureDetector(
                onTap: () => setState(() => showAll = !showAll),
                child: Text(
                  showAll ? 'Read less' : 'Read more',
                  style: const TextStyle(
                    color: blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EditExperienceSheet extends StatefulWidget {
  final List<String> experiences;
  final Function(List<String>) onSave;

  const EditExperienceSheet({
    super.key,
    required this.experiences,
    required this.onSave,
  });

  @override
  State<EditExperienceSheet> createState() => _EditExperienceSheetState();
}

class _EditExperienceSheetState extends State<EditExperienceSheet> {
  late List<TextEditingController> controllers;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controllers =
        widget.experiences.map((e) => TextEditingController(text: e)).toList();
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addExperience() {
    setState(() {
      controllers.add(TextEditingController());
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeExperience(int index) {
    setState(() {
      controllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: _scrollController,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 5,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Edit Experiences',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // 🔁 Dynamic experience fields with delete icon
              ...List.generate(controllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controllers[index],
                          maxLines: null,
                          style: const TextStyle(color: white),
                          decoration: InputDecoration(
                            hintText: 'Experience ${index + 1}',
                            hintStyle: const TextStyle(color: white_gray),
                            filled: true,
                            fillColor: black_gray,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) {
                            setState(() {}); // Refresh live preview
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      DeleteIconButton(
                        onPressed: () => _removeExperience(index),
                      ),
                    ],
                  ),
                );
              }),

              // ➕ Add new button
              TextButton.icon(
                onPressed: _addExperience,
                icon: const Icon(Icons.add, color: blue),
                label: const Text(
                  'Add Experience',
                  style: TextStyle(color: blue),
                ),
              ),

              const SizedBox(height: 20),

              // 🔍 Live Preview (optional)
              if (controllers.any((c) => c.text.trim().isNotEmpty)) ...[
                const Text(
                  'Preview:',
                  style: TextStyle(
                      color: white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: controllers
                        .where((c) => c.text.trim().isNotEmpty)
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle,
                                      color: blue, size: 6),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.text.trim(),
                                      style: const TextStyle(
                                        color: white_gray,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // ✅ Save
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final updated = controllers
                      .map((c) => c.text.trim())
                      .where((text) => text.isNotEmpty)
                      .toList();
                  widget.onSave(updated);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EditEducationSheet extends StatefulWidget {
  final List<String> educations;
  final Function(List<String>) onSave;

  const EditEducationSheet({
    super.key,
    required this.educations,
    required this.onSave,
  });

  @override
  State<EditEducationSheet> createState() => _EditEducationSheetState();
}

class _EditEducationSheetState extends State<EditEducationSheet> {
  late List<TextEditingController> controllers;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controllers =
        widget.educations.map((e) => TextEditingController(text: e)).toList();
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addExperience() {
    setState(() {
      controllers.add(TextEditingController());
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeExperience(int index) {
    setState(() {
      controllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: _scrollController,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 5,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Edit Experiences',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // 🔁 Dynamic experience fields with delete icon
              ...List.generate(controllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controllers[index],
                          maxLines: null,
                          style: const TextStyle(color: white),
                          decoration: InputDecoration(
                            hintText: 'Experience ${index + 1}',
                            hintStyle: const TextStyle(color: white_gray),
                            filled: true,
                            fillColor: black_gray,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) {
                            setState(() {}); // Refresh live preview
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      DeleteIconButton(
                        onPressed: () => _removeExperience(index),
                      ),
                    ],
                  ),
                );
              }),

              // ➕ Add new button
              TextButton.icon(
                onPressed: _addExperience,
                icon: const Icon(Icons.add, color: blue),
                label: const Text(
                  'Add Experience',
                  style: TextStyle(color: blue),
                ),
              ),

              const SizedBox(height: 20),

              // 🔍 Live Preview (optional)
              if (controllers.any((c) => c.text.trim().isNotEmpty)) ...[
                const Text(
                  'Preview:',
                  style: TextStyle(
                      color: white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: black_gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: controllers
                        .where((c) => c.text.trim().isNotEmpty)
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle,
                                      color: blue, size: 6),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.text.trim(),
                                      style: const TextStyle(
                                        color: white_gray,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // ✅ Save
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final updated = controllers
                      .map((c) => c.text.trim())
                      .where((text) => text.isNotEmpty)
                      .toList();
                  widget.onSave(updated);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DeleteIconButton extends StatefulWidget {
  final VoidCallback onPressed;

  const DeleteIconButton({super.key, required this.onPressed});

  @override
  State<DeleteIconButton> createState() => _DeleteIconButtonState();
}

class _DeleteIconButtonState extends State<DeleteIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.redAccent.withOpacity(0.4),
                Colors.red.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.delete_forever_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class ExpandingResumeField extends StatefulWidget {
  final TextEditingController controller;

  const ExpandingResumeField({super.key, required this.controller});

  @override
  State<ExpandingResumeField> createState() => _ExpandingResumeFieldState();
}

class _ExpandingResumeFieldState extends State<ExpandingResumeField> {
  final int maxChars = 700;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: blue_gray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // 📝 TextField
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: TextFormField(
              controller: widget.controller, // ✅ use controller
              focusNode: _focusNode,
              maxLines: null,
              maxLength: maxChars,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  const SizedBox.shrink(),
              style: const TextStyle(color: white, fontSize: 15),
              cursorColor: white,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Write a short resume or summary...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: white_gray,
                ),
              ),
              onChanged: (_) {
                setState(() {}); // ✅ To update character counter below
              },
            ),
          ),

          // 🔢 Custom character counter
          Positioned(
            right: 0,
            bottom: -5,
            child: Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: (maxChars - widget.controller.text.length) <= 20
                      ? Colors.redAccent
                      : white_gray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                child: Text(
                    '${maxChars - widget.controller.text.length} characters left'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageChipsSelector extends StatefulWidget {
  final String searchText;
  final Set<String> selectedLanguages; // ✅ Add this
  final Function(Set<String>) onSelectionChanged; // ✅ Callback to parent

  const LanguageChipsSelector({
    super.key,
    required this.searchText,
    required this.selectedLanguages,
    required this.onSelectionChanged,
  });

  @override
  State<LanguageChipsSelector> createState() => _LanguageChipsSelectorState();
}

const List<String> allLanguages = [
  'Albanais',
  'Amharique',
  'Arabe',
  'Arménien',
  'Azéri',
  'Baloutche',
  'Bengali',
  'Berbère',
  'Biélorusse',
  'Bhojpouri',
  'Bulgare',
  'Birman',
  'Catalan',
  'Chewa',
  'Chichewa',
  'Chittagonien',
  'Corse',
  'Tchèque',
  'Danois',
  'Néerlandais',
  'Anglais',
  'Fidjien',
  'Finnois',
  'Français',
  'Peul',
  'Galicien',
  'Géorgien',
  'Allemand',
  'Grec',
  'Groenlandais',
  'Gujarati',
  'Créole haïtien',
  'Haoussa',
  'Hébreu',
  'Hindi',
  'Hmong',
  'Hongrois',
  'Igbo',
  'Ilocano',
  'Indonésien',
  'Italien',
  'Japonais',
  'Javanais',
  'Kabyle',
  'Kannada',
  'Kazakh',
  'Khmer',
  'Kinyarwanda',
  'Coréen',
  'Kurde',
  'Laotien',
  'Luxembourgeois',
  'Madurais',
  'Malais',
  'Malayalam',
  'Macédonien',
  'Maori',
  'Marathi',
  'Mongol',
  'Mossi',
  'Népalais',
  'Norvégien',
  'Oromo',
  'Pachto',
  'Persan',
  'Polonais',
  'Portugais',
  'Pendjabi',
  'Quechua',
  'Roumain',
  'Russe',
  'Samoan',
  'Serbo-croate',
  'Shona',
  'Sindhi',
  'Singhalais',
  'Slovaque',
  'Somali',
  'Espagnol',
  'Swahili',
  'Suédois',
  'Soundanais',
  'Tagalog',
  'Tamoul',
  'Télougou',
  'Thaï',
  'Tigré',
  'Tigrinya',
  'Turc',
  'Ukrainien',
  'Ourdou',
  'Ouzbek',
  'Vietnamien',
  'Wolof',
  'Xhosa',
  'Yiddish',
  'Yoruba',
  'Zoulou'
];

class _LanguageChipsSelectorState extends State<LanguageChipsSelector> {
  late Set<String> localSelection;

  @override
  void initState() {
    super.initState();
    localSelection = {...widget.selectedLanguages}; // copy
  }

  @override
  Widget build(BuildContext context) {
    final filteredLanguages = allLanguages
        .where((lang) =>
            lang.toLowerCase().contains(widget.searchText.toLowerCase()))
        .toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: filteredLanguages.map((language) {
        final isSelected = localSelection.contains(language);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (selectedLanguages.contains(language)) {
                selectedLanguages.remove(language);
              } else {
                selectedLanguages.add(language);
              }
              widget.onSelectionChanged(localSelection); // notify parent
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? blue : blue_gray,
              borderRadius: BorderRadius.circular(100),
              border:
                  isSelected ? null : Border.all(color: white_gray, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            child: Text(
              language,
              style: TextStyle(
                color: isSelected ? black : white_gray,
                fontSize: 15,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LanguageDetailsSheet extends StatefulWidget {
  const _LanguageDetailsSheet({super.key});

  @override
  State<_LanguageDetailsSheet> createState() => _LanguageDetailsSheetState();
}

Set<String> tempSelectedLanguages =
    Set.from(selectedLanguages); // Clone initial state

class _LanguageDetailsSheetState extends State<_LanguageDetailsSheet> {
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 7,
                  decoration: BoxDecoration(
                      color: white_gray,
                      borderRadius: BorderRadius.circular(100)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // ❌ Cancel button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {}); // Close the bottom sheet
                    },
                    child: const Icon(
                      Icons.close,
                      color: white_gray,
                    ),
                  ),

                  const Expanded(child: SizedBox(width: 1)),

                  // ✅ Confirm button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close the sheet
                      setState(() {}); // Refresh parent if needed
                    },
                    child: const Icon(
                      Icons.check,
                      color: white_gray,
                    ),
                  ),
                ],
              ),

              const Center(
                child: Text(
                  'Languages Spoken',
                  style: TextStyle(
                      color: white, fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select languages you know to add them to your profile',
                style: TextStyle(
                  color: white_gray,
                  fontSize: 16,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                decoration: BoxDecoration(
                  color: black_gray,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: white_gray, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        onChanged: (value) {
                          setState(() {
                            _searchText = value;
                          });
                        },
                        style: const TextStyle(color: white, fontSize: 16),
                        cursorColor: white_gray,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search languages',
                          hintStyle: TextStyle(color: white_gray, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              ), //here there should be a wrap or something this is the default container
              LanguageChipsSelector(
                searchText: _searchText,
                selectedLanguages: selectedLanguages,
                onSelectionChanged: (updatedSelection) {
                  setState(() {
                    selectedLanguages = updatedSelection;
                  });
                },
              )

              // 🔥 Add more widgets below as needed...
            ],
          ),
        );
      },
    );
  }
}

final Set<String> softSkills = {};

class AnimatedCheckMark extends StatefulWidget {
  final double size;

  const AnimatedCheckMark({super.key, this.size = 60});

  @override
  State<AnimatedCheckMark> createState() => _AnimatedCheckMarkState();
}

class _AnimatedCheckMarkState extends State<AnimatedCheckMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: CheckMarkPainter(_animation),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class CheckMarkPainter extends CustomPainter {
  final Animation<double> animation;

  CheckMarkPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double progress = animation.value;

    final double radius = (size.width / 2) - 6;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // 1. Draw circular progress arc (0.0 to 0.6)
    if (progress <= 0.6) {
      final double sweepAngle = 2 * pi * (progress / 0.6);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        paint,
      );
    }

    // 2. Draw checkmark after 0.6
    if (progress > 0.6) {
      // Draw full circle first
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi,
        false,
        paint,
      );

      final double t = (progress - 0.6) / 0.4;
      final Offset start = Offset(size.width * 0.28, size.height * 0.52);
      final Offset mid = Offset(size.width * 0.45, size.height * 0.68);
      final Offset end = Offset(size.width * 0.72, size.height * 0.38);

      final Path path = Path();
      if (t < 0.5) {
        final Offset current = Offset.lerp(start, mid, t * 2)!;
        path.moveTo(start.dx, start.dy);
        path.lineTo(current.dx, current.dy);
      } else {
        final Offset current = Offset.lerp(mid, end, (t - 0.5) * 2)!;
        path.moveTo(start.dx, start.dy);
        path.lineTo(mid.dx, mid.dy);
        path.lineTo(current.dx, current.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CheckMarkPainter oldDelegate) => true;
}

class WaveWipeTextSwitcher extends StatefulWidget {
  final String text;

  const WaveWipeTextSwitcher({super.key, required this.text});

  @override
  State<WaveWipeTextSwitcher> createState() => _WaveWipeTextSwitcherState();
}

class _WaveWipeTextSwitcherState extends State<WaveWipeTextSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  String _currentText = '';
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
    _previousText = '';
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward(); // ✅ Trigger animation on first load
  }

  @override
  void didUpdateWidget(covariant WaveWipeTextSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _previousText = _currentText;
      _currentText = widget.text;
      _controller.forward(from: 0); // ✅ Trigger animation on new upload
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.6;
    const height = 24.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        final splitX = width * progress;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  clipper: _LeftClipper(x: splitX),
                  child: Text(
                    _previousText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: white_gray,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRect(
                  clipper: _RightClipper(x: splitX),
                  child: Opacity(
                    opacity: progress,
                    child: Text(
                      _currentText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: white_gray,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class LoadingBars extends StatefulWidget {
  const LoadingBars({super.key});

  @override
  State<LoadingBars> createState() => _LoadingBarsState();
}

class _LoadingBarsState extends State<LoadingBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int barCount = 4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  double _barValue(double controllerValue, int index) {
    final delay = index * 0.15;
    final t = (controllerValue + delay) % 1.0;
    return TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(barCount, (i) {
              final scaleY = _barValue(_controller.value, i);
              return Transform.scale(
                scaleY: scaleY,
                child: Container(
                  width: 6,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _LoadingBar extends AnimatedWidget {
  const _LoadingBar({required Animation<double> animation})
      : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleY: animation.value,
      child: Container(
        width: 6,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  final double x;
  _LeftClipper({required this.x});

  @override
  Rect getClip(Size size) => Rect.fromLTWH(x, 0, size.width - x, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) => oldClipper.x != x;
}

class _RightClipper extends CustomClipper<Rect> {
  final double x;
  _RightClipper({required this.x});

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(covariant _RightClipper oldClipper) => oldClipper.x != x;
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 14;
    const dashSpace = 6;

    final paint = Paint()
      ..color = blue
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final RRect rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    final Path path = Path()..addRRect(rRect);
    final PathMetrics pathMetrics = path.computeMetrics();
    for (final PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final Path extractPath = pathMetric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ContactInfoSection extends StatefulWidget {
  final String phoneNumber;
  final String address;
  final void Function(String phone, String address) onSave;

  const ContactInfoSection({
    super.key,
    required this.phoneNumber,
    required this.address,
    required this.onSave,
  });

  @override
  State<ContactInfoSection> createState() => _ContactInfoSectionState();
}

class _ContactInfoSectionState extends State<ContactInfoSection> {
  late String phone;
  late String address;

  @override
  void initState() {
    super.initState();
    phone = widget.phoneNumber;
    address = widget.address;
  }

  void _openEditModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditContactInfoSheet(
        initialPhone: phone,
        initialAddress: address,
        onSave: (updatedPhone, updatedAddress) {
          setState(() {
            phone = updatedPhone;
            address = updatedAddress;
          });
          widget.onSave(updatedPhone, updatedAddress);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        decoration: BoxDecoration(
          color: blue_gray,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openEditModal,
                  child: const Icon(Icons.edit, color: white_gray, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              'Phone: $phone',
              style: const TextStyle(color: white_gray, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Address: $address',
              style: const TextStyle(color: white_gray, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class EditContactInfoSheet extends StatefulWidget {
  final String initialPhone;
  final String initialAddress;
  final void Function(String phone, String address) onSave;

  const EditContactInfoSheet({
    super.key,
    required this.initialPhone,
    required this.initialAddress,
    required this.onSave,
  });

  @override
  State<EditContactInfoSheet> createState() => _EditContactInfoSheetState();
}

class _EditContactInfoSheetState extends State<EditContactInfoSheet> {
  late TextEditingController phoneController;
  late TextEditingController addressController;

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController(text: widget.initialPhone);
    addressController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 6,
                  decoration: BoxDecoration(
                    color: white_gray,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Contact Info',
                style: TextStyle(
                  color: white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: phoneController,
                style: const TextStyle(color: white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: white_gray),
                  filled: true,
                  fillColor: black_gray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: addressController,
                style: const TextStyle(color: white),
                decoration: const InputDecoration(
                  labelText: 'Address',
                  labelStyle: TextStyle(color: white_gray),
                  filled: true,
                  fillColor: black_gray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  widget.onSave(
                    phoneController.text.trim(),
                    addressController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
