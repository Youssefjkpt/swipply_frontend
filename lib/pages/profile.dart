import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/cv.dart';
import 'package:swipply/pages/subscriptions.dart';
import 'package:swipply/widgets/auto_apply_card.dart';
import 'package:swipply/widgets/cv_chevker.dart';
import 'package:swipply/widgets/like_container_profile.dart';
import 'package:swipply/widgets/mini_subsciption_plans.dart';
import 'package:swipply/widgets/subscription_profile_container.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Profile extends StatefulWidget {
  final ValueNotifier<int> currentTabIndex;
  const Profile({super.key, required this.currentTabIndex});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  File? _profileImage;
  String? sanitizeField(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '{}' || str == 'null') return null;
    return str;
  }

  bool _hasFetchedOnThisView = false;

  @override
  void initState() {
    super.initState();
    // Always fetch once on first appearance:
    _fetchIfVisible();

    // And listen for tab changes:
    widget.currentTabIndex.addListener(_fetchIfVisible);
    fetchEmployeeData();
  }

  @override
  void dispose() {
    widget.currentTabIndex.removeListener(_fetchIfVisible);
    super.dispose();
  }

  void _fetchIfVisible() {
    // If the current tab index is 2 (Profile), fetch data
    // and reset the flag if needed.
    if (widget.currentTabIndex.value == 2) {
      // Optionally debounce so you don't hit the server repeatedly:
      if (!_hasFetchedOnThisView) {
        fetchEmployeeData();
        _hasFetchedOnThisView = true;
      }
    } else {
      // Reset when switching away, so returning will fetch again:
      _hasFetchedOnThisView = false;
    }
  }

  String? resume;
  List<String> experience = [];
  List<String> education = [];
  List<String> languages = [];
  List<String> interests = [];
  List<String> softSkills = [];
  List<dynamic> certificates = [];
  List<dynamic> skillsAndProficiency = [];
  Map<String, dynamic>? weeklyAvailability;
  String? availability;
  Future<void> fetchEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      print("❌ No user ID found");
      return;
    }

    try {
      final employeeResponse = await http.get(
        Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'),
      );

      final userResponse = await http.get(
        Uri.parse('$BASE_URL_AUTH/users/$userId'),
      );

      if (employeeResponse.statusCode == 200 &&
          userResponse.statusCode == 200) {
        final employeeData = jsonDecode(employeeResponse.body);
        final userData = jsonDecode(userResponse.body);

        setState(() {
          _jobTitle = sanitizeField(userData['job_title']) ?? '';
          profilePicturePath = sanitizeField(userData['profile_photo_url']);

          fullName = sanitizeField(userData['full_name']);
          resume = sanitizeField(employeeData['resume']);

          experience = (employeeData['experience'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          education = (employeeData['education'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          languages = (employeeData['languages'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          interests = (employeeData['interests'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          softSkills = (employeeData['soft_skills'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          certificates = employeeData['certificates'] ?? [];
          skillsAndProficiency = employeeData['skills_and_proficiency'] ?? [];

          weeklyAvailability = employeeData['weekly_availability'];
          availability = employeeData['availability'];
        });

        await CVChecker.updateCVStatus(employeeData);
        final status = await CVChecker.isCVIncomplete();
        final missing = await CVChecker.getMissingFields();

        setState(() {
          isCVIncomplete = status;
          missingFields = missing;
        });

        print("✅ Employee and user data loaded successfully");
      } else {
        print(
            "❌ Failed to fetch data: ${employeeResponse.body} | ${userResponse.body}");
      }
    } catch (e) {
      print("❌ Error fetching profile data: $e");
    }
  }

  String? fullName;
  String? profilePicturePath;

  bool isEditing = false;
  String _jobTitle = 'Etudiant';
  bool isCVIncomplete = false;
  List<String> missingFields = [];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
      await _uploadProfilePhoto();
    }
  }

  bool _hasLoadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedOnce) {
      fetchEmployeeData();
      _hasLoadedOnce = true;
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _hasLoadedOnce = false;
    });
    await fetchEmployeeData();
  }

  Future<void> _uploadProfilePhoto() async {
    if (_profileImage == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) {
      print('❌ No user ID found');
      return;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$BASE_URL_AUTH/upload-profile-photo/$userId'),
    );

    request.files
        .add(await http.MultipartFile.fromPath('photo', _profileImage!.path));
    final response = await request.send();

    if (response.statusCode == 200) {
      final resBody = await response.stream.bytesToString();
      final jsonData = json.decode(resBody);
      final photoPath = jsonData['path'];

      await prefs.setString('profile_picture_path', photoPath);

      setState(() {
        profilePicturePath = photoPath;
      });

      print('✅ Profile photo uploaded and path saved: $photoPath');
    } else {
      print('❌ Failed to upload profile photo: ${response.statusCode}');
    }
  }

  final List<String> features = [
    "Préférence de type d'emploi",
    "Filtrer par salaire",
    "Candidature automatique IA: 1h/jour",
    "Annuler likes/offres",
    "Candidatures prioritaires",
    "Aucune publicité",
    "Meilleures offres pour vous",
  ];

  final List<bool> includedInFree = [
    true,
    false,
    false,
    false,
    false,
    false,
    false
  ];
  final List<bool> includedInGold = [
    true,
    true,
    true,
    true,
    false,
    false,
    false
  ];
  final List<bool> includedInPlatinum = [
    true,
    true,
    true,
    true,
    true,
    true,
    true
  ];

  @override
  Widget build(BuildContext context) {
    print("CV incomplete status: $isCVIncomplete");
    print("Missing fields: $missingFields");
    print("isCVIncomplete: $isCVIncomplete");

    return Scaffold(
      backgroundColor: black,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: Colors.white,
        backgroundColor: Colors.black,
        child: ListView(children: [
          if (isCVIncomplete)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 15, right: 15),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                            backgroundColor: blue_gray,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: const Text("Champs manquants",
                                style: TextStyle(
                                    color: white, fontWeight: FontWeight.bold)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: missingFields
                                  .map((field) => Row(
                                        children: [
                                          const Icon(Icons.close_rounded,
                                              color: Colors.redAccent,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Text(field,
                                              style: const TextStyle(
                                                  color: white_gray,
                                                  fontSize: 14)),
                                        ],
                                      ))
                                  .toList(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Fermer",
                                    style: TextStyle(color: Colors.white)),
                              )
                            ],
                          ));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.15),
                    border:
                        Border.all(color: const Color(0xFFFF3B30), width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFF3B30), size: 26),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Votre CV est incomplet. Touchez pour voir les sections manquantes.",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54)
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded,
                        color: white, size: 30),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showEditBottomSheet,
                      child: const Text(
                        'Modifier',
                        style: TextStyle(
                          color: white_gray,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null &&
                                profilePicturePath != null
                            ? ClipOval(
                                child: SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: FadeInImage.assetNetwork(
                                    placeholder:
                                        progress, // Use a transparent loader or create one
                                    image: '$BASE_URL_AUTH$profilePicturePath',
                                    fit: BoxFit.cover,
                                    imageErrorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              )
                            : (_profileImage == null &&
                                    profilePicturePath == null)
                                ? const Icon(Icons.person,
                                    size: 60, color: Colors.white70)
                                : null,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black87,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                Text(
                  sanitizeField(fullName) ?? 'Mon nom',
                  style: const TextStyle(
                      color: white, fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 5),

                // Job title field
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sanitizeField(_jobTitle) ?? 'UX Designer',
                      style: const TextStyle(color: white_gray, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.verified,
                        color: Colors.greenAccent, size: 18),
                  ],
                ),
                const SizedBox(
                  height: 30,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AutoApplyBadge(),
                    SuperLikeBadge(),
                    GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => FullSubscriptionPage())),
                        child: SubscriptionBadge())
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                const Row(
                  children: [
                    Text(
                      'CV',
                      style: TextStyle(
                        color: white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                        child: SizedBox(
                      width: 1,
                    )),
                    Text(
                      'Créer un CV',
                      style:
                          TextStyle(color: Color.fromARGB(217, 36, 120, 255)),
                    )
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const CV())),
                  child: Container(
                    decoration: BoxDecoration(
                        color: blue_gray,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.05,
                            ),
                            Container(
                              width: 50,
                              decoration: BoxDecoration(
                                  color: blue,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      left: 10, right: 10, top: 3, bottom: 3),
                                  child: Text(
                                    'CV',
                                    style: TextStyle(
                                        color: blue_gray,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: SizedBox(
                                width: 1,
                              ),
                            ),
                            Text(
                              sanitizeField(fullName) ?? 'Mon nom',
                              style: TextStyle(
                                  color: white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            const Expanded(
                              child: SizedBox(
                                width: 1,
                              ),
                            ),
                            Container(
                              width: 50,
                              decoration: BoxDecoration(
                                  color: blue,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      left: 10, right: 10, top: 3, bottom: 3),
                                  child: Text(
                                    'PDF',
                                    style: TextStyle(
                                        color: blue_gray,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.05,
                            )
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: SizedBox(
                              width: 1,
                            )),
                            Text(
                              sanitizeField(_jobTitle) ?? 'UX Designer',
                              style: TextStyle(
                                  color: white_gray,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                                child: SizedBox(
                              width: 1,
                            )),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width * 0.05,
                            right: MediaQuery.of(context).size.width * 0.05,
                          ),
                          child: Text(
                            sanitizeField(resume) ??
                                'Aucun CV ajouté pour le moment.',
                            style: const TextStyle(
                              color: white_gray,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                ),

                const MiniSubscriptionSwiper(),
              ],
            ),
          )
        ]),
      ),
    );
  }

  void _showEditBottomSheet() {
    final nameController = TextEditingController(
      text: (fullName != null && fullName!.trim().isNotEmpty)
          ? fullName
          : 'Mon nom',
    );
    final jobController = TextEditingController(
      text: (_jobTitle.trim().isNotEmpty) ? _jobTitle : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              maxChildSize: 0.75,
              minChildSize: 0.4,
              builder: (_, controller) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.95),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: ListView(
                    controller: controller,
                    shrinkWrap: true,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Modifier le profil",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close,
                                color: Colors.white54, size: 24),
                          )
                        ],
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: nameController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Nom",
                          labelStyle:
                              const TextStyle(color: white_gray, fontSize: 14),
                          enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: white_gray, width: 1.2),
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 1.5),
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: jobController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Intitulé de poste",
                          labelStyle:
                              const TextStyle(color: white_gray, fontSize: 14),
                          enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: white_gray, width: 1.2),
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 1.5),
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                        ),
                      ),
                      const SizedBox(height: 30),
                      GestureDetector(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('user_id');
                          if (userId == null) return;

                          final response = await http.put(
                            Uri.parse('$BASE_URL_AUTH/users/$userId'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'full_name': nameController.text.trim(),
                              'job_title': jobController.text.trim(),
                            }),
                          );

                          if (response.statusCode == 200) {
                            if (mounted) {
                              setState(() {
                                fullName = nameController.text;
                                _jobTitle = jobController.text;
                              });

                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            }
                          } else {
                            print("❌ Failed to update user: ${response.body}");
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 15, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF00FFAA), Color(0xFF00C28C)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FFAA).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: const Center(
                            child: Text("Enregistrer",
                                style: TextStyle(
                                    color: black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ));
      },
    );
  }
}
