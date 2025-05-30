import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:swipply/env.dart';
import 'package:swipply/widgets/adress.dart';
import 'package:swipply/widgets/check_mark_green_design.dart';
import 'package:swipply/widgets/cv_chevker.dart';
import 'package:swipply/widgets/delete_icon.dart';
import 'package:swipply/widgets/edit_education_sheet.dart';
import 'package:swipply/widgets/education_section.dart';
import 'package:swipply/widgets/language_chips.dart';
import 'package:swipply/widgets/loading_bars.dart';
import 'package:swipply/widgets/wave_wipe_cv_name.dart';

class InterestsSection extends StatelessWidget {
  final List<String> interests;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final VoidCallback onEdit;

  const InterestsSection({
    Key? key,
    required this.interests,
    required this.showAll,
    required this.onToggleShowAll,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final count = interests.length;
    final toShow = showAll ? interests : interests.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: blue_gray,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text(
            'Intérêts',
            style: TextStyle(
              color: white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit, color: white_gray, size: 20),
          ),
        ]),
        const SizedBox(height: 15),
        if (count == 0)
          const Text(
            'Aucun intérêt ajouté',
            style: TextStyle(color: white_gray, fontSize: 15),
          )
        else
          ...toShow.map((i) => Padding(
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
                        i,
                        style: const TextStyle(color: white_gray, fontSize: 15),
                      )),
                    ]),
              )),
        if (count > 3)
          GestureDetector(
            onTap: onToggleShowAll,
            child: Text(
              showAll ? 'Voir moins' : 'Voir plus',
              style: const TextStyle(
                color: blue,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ]),
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
  List<String> softSkills = [];
  String? address;
  String userFullName = '';
  String? userId;
  String _jobTitle = '';
  bool _showAllEdu = false;
  late List<String> languages;
  String _uploadedFileName = 'Importer un Doc/Docx/PDF';
  late AnimationController _checkmarkController;
  Future<void> fetchUserData() async {
    final id = await getUserId();
    final token = await getAuthToken();

    if (id == null || token == null) return;

    final response = await http.get(
      Uri.parse('$BASE_URL_AUTH/users/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        userFullName = data['full_name'] ?? '';
        userEmail = data['email'] ?? '';
        phone = data['phone_number'] ?? '';
        address = data['address'] ?? '';
        _jobTitle = data['job_title'] ?? '';
        // ✅ Only use default text if no interests are saved
        if (data['interests'] != null && data['interests'].isNotEmpty) {
          selectedInterests = List<String>.from(data['interests']);
        } else {
          selectedInterests = ['Aucun intérêt ajouté'];
        }
      });
      resumeController?.text = data['personalized_resume'] ?? '';
      if (data['skillsAndProficiency'] != null &&
          data['skillsAndProficiency'].isNotEmpty) {
        skills = List<Map<String, dynamic>>.from(data['skillsAndProficiency']);
      } else {
        skills = [];
      } // ✅ Fetch Soft Skills
      if (data['softSkills'] != null && data['softSkills'].isNotEmpty) {
        softSkills = List<String>.from(data['softSkills']);
      } else {
        softSkills = [];
      } // ✅ Fetch Languages
      if (data['languages'] != null && data['languages'].isNotEmpty) {
        selectedLanguages = Set<String>.from(data['languages']);
      } else {
        selectedLanguages = {};
      }
    }
  }

  void _openEditInterestsSheet() async {
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditInterestsSheet(
        initialInterests: selectedInterests,
        onSave: (newList) => Navigator.pop(context, newList),
      ),
    );
    if (updated != null) {
      setState(() {
        selectedInterests = updated;
      });
    }
  }

  Future<void> fetchEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;
    final userResponse = await http.get(
      Uri.parse('$BASE_URL_AUTH/users/$userId'),
    );
    final userData = jsonDecode(userResponse.body);
    try {
      final resp = await http.get(
        Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode != 200) {
        print('Failed to load employee: ${resp.statusCode}');
        return;
      }

      final employeeData = jsonDecode(resp.body) as Map<String, dynamic>;

      // 🔍 Normalize the `experience` field:
      final rawExp = employeeData['experience'];
      List<String> fetchedExperiences;

      if (rawExp is String) {
        final str = rawExp.trim();

        if (str.startsWith('{') && str.endsWith('}')) {
          // Postgres array literal: extract values between quotes
          final matches = RegExp(r'"([^"]*)"').allMatches(str);
          fetchedExperiences = matches.map((m) => m.group(1)!.trim()).toList();
        } else {
          // Fallback: newline‐separated
          fetchedExperiences = str
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } else if (rawExp is List) {
        fetchedExperiences = rawExp.map((e) => e.toString().trim()).toList();
      } else {
        fetchedExperiences = [];
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final rawEdu = data['education'];
      List<String> fetchedEducations;
      if (rawEdu is String) {
        final str = rawEdu.trim();
        if (str.startsWith('{') && str.endsWith('}')) {
          fetchedEducations = RegExp(r'"([^"]*)"')
              .allMatches(str)
              .map((m) => m.group(1)!.trim())
              .toList();
        } else {
          fetchedEducations = str
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } else if (rawEdu is List) {
        fetchedEducations = rawEdu.map((e) => e.toString().trim()).toList();
      } else {
        fetchedEducations = [];
      }
      final rawSkills = employeeData['skills_and_proficiency'];
      List<Map<String, dynamic>> fetchedSkills;

      if (rawSkills is String) {
        final str = rawSkills.trim();
        if (str.startsWith('{') && str.endsWith('}')) {
          // array‐literal: extract each JSON‐ish fragment
          final matches = RegExp(r'\{([^}]*)\}').allMatches(str);
          fetchedSkills = matches.map((m) {
            // each m.group(1) is like '"skill": "Dart", "proficiency": 0.8'
            final inner = '{${m.group(1)}}';
            return Map<String, dynamic>.from(jsonDecode(inner));
          }).toList();
        } else {
          // fallback: newline separated JSON objects
          fetchedSkills = str
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .map((line) => Map<String, dynamic>.from(jsonDecode(line)))
              .toList();
        }
      } else if (rawSkills is List) {
        fetchedSkills =
            rawSkills.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        fetchedSkills = [];
      }
      for (var skill in fetchedSkills) {
        final raw = skill['proficiency'] ?? skill['level'] ?? 0;
        skill['level'] =
            (raw is num) ? raw.toDouble() : double.parse(raw.toString());
      }
// t

      print('✅ parsedSkills: $fetchedSkills');
      final rawInt = employeeData['interests'];
      List<String> fetchedInterests;

      if (rawInt is String) {
        final str = rawInt.trim();
        if (str.startsWith('{') && str.endsWith('}')) {
          // Postgres array literal: extract values between quotes
          fetchedInterests = RegExp(r'"([^"]*)"')
              .allMatches(str)
              .map((m) => m.group(1)!.trim())
              .toList();
        } else {
          // Fallback: newline-separated
          fetchedInterests = str
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } else if (rawInt is List) {
        fetchedInterests = rawInt.map((e) => e.toString().trim()).toList();
      } else {
        fetchedInterests = [];
      }
      final rawSoft = employeeData['soft_skills'];
      List<String> fetchedSoft;
      if (rawSoft is String) {
        final str = rawSoft.trim();
        if (str.startsWith('{') && str.endsWith('}')) {
          fetchedSoft = RegExp(r'"([^"]*)"')
              .allMatches(str)
              .map((m) => m.group(1)!.trim())
              .toList();
        } else {
          fetchedSoft = str
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } else if (rawSoft is List) {
        fetchedSoft = rawSoft.map((e) => e.toString().trim()).toList();
      } else {
        fetchedSoft = [];
      }
      print('✅ parsedSoftSkills: $fetchedSoft');
      fullName = sanitizeField(userData['full_name']);
      phone = sanitizeField(userData['phone_number']);
      address = sanitizeField(userData['address']);
      print('🔍 raw phone_number: ${userData['phone_number']}');
      print('🔍 raw address:  ${userData['address']}');
      print('✅ parsedEducations: $fetchedEducations');

      setState(() {
        experiences = fetchedExperiences;
        educations = fetchedEducations;

        // …and your other fields…
        resume = sanitizeField(employeeData['resume']);
        selectedInterests = fetchedInterests;
        softSkills = fetchedSoft;
        skills = fetchedSkills;
        phone = sanitizeField(userData['phone_number']);
        address = sanitizeField(userData['address']);
        // etc.
      });
    } catch (e) {
      print('Error fetching employee data: $e');
    }
  }

  String? sanitizeField(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '{}' || str == 'null') return null;
    return str;
  }

  /// Helper to parse fields stored as either Postgres‐array literal or newline/string
  List<String> _parsePossiblyArrayOrString(dynamic raw) {
    if (raw is String) {
      final str = raw.trim();
      if (str.startsWith('{') && str.endsWith('}')) {
        return RegExp(r'"([^"]*)"')
            .allMatches(str)
            .map((m) => m.group(1)!.trim())
            .toList();
      } else {
        return str
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } else if (raw is List) {
      return raw.map((e) => e.toString().trim()).toList();
    }
    return [];
  }

  void fetchUserId() async {
    final id = await getUserId();
    setState(() {
      userId = id;
    });
    print("🟢 Logged-in user_id: $userId");
  }

  // 1) Drop the async/await
  void _openEditSoftSkillsSheet() {
    showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditSoftSkillsSheet(
        initialSoftSkills: softSkills,
        // onSave no longer pops
        onSave: (newList) => setState(() {
          softSkills = newList;
        }),
      ),
    ).then((updated) {
      // This .then will receive updated only if the sheet popped with a value.
      if (updated != null) {
        setState(() {
          softSkills = updated;
        });
      }
    });
  }

  String startDateText = 'Immédiatement';
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
    userId ??= await getUserId(); // ✅ assigns only if null

    final token =
        await getAuthToken(); // no need to assign globally if you only use it inside

    if (userId == null || token == null) {
      showUploadPopup(context, errorMessage: "ID ou jeton manquant");
      return;
    }

    showUploadPopup(context); // Show loading popup

    final safePhone = phone?.trim();
    final safeAddress = address?.trim();
    bool _showAllInterests = false;
    final data = {
      'email': userEmail,
      if (safePhone != null && safePhone.isNotEmpty) 'phone': safePhone,
      if (safeAddress != null && safeAddress.isNotEmpty) 'address': safeAddress,
      'resume': resumeController?.text.trim(),
      'experience': experiences,
      'education': educations,
      'availability': startDateText,
      'weeklyAvailability': weeklyAvailability,
      'interests': selectedInterests.isEmpty ? null : selectedInterests,
      'softSkills': softSkills.toList(),
      'skillsAndProficiency': skills,
      'languages': selectedLanguages.toList(),
      'certificates': certificates,
      'linkedin_url': null,
      'lettre_de_motivation': null,
      'fullName': userFullName,
      'available_start_date': null,
      'job_title': _jobTitle, // required for backend insert
      'job_id': '0e86aea3-1236-4a41-a13a-e249d2f24aea',
    };

    final body = {
      'user_id': userId,
      'data': data,
    };

    try {
      print("📦 Sending saveCV body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse("$BASE_URL_AUTH/api/save-cv"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      print("📨 Save CV Response: ${response.statusCode}");
      print("📨 Save CV Body: ${response.body}");

      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('cv_complete', true);
        showSuccessCheckPopup(); // ✅ Success animation
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('cv_complete', false);
        showUploadPopup(context, errorMessage: "Erreur d’enregistrement");
      }
    } catch (e) {
      Navigator.of(context).pop();
      showUploadPopup(context, errorMessage: "Erreur: ${e.toString()}");
    }
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  UploadStatus _status = UploadStatus.idle;
  double _uploadProgress = 0;
  Map<String, dynamic>? parsedCVData;
  bool _showLoadingPopup = false;
  List<Map<String, dynamic>> certificates = [];
  String userEmail = '';
  String userPhone = '';
  final Set<String> incompleteFields = {};

  String? selectedFileName = 'Importer un Doc/Docx/PDF';
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
      final userId = await getUserId(); // already declared in your code

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$BASE_URL_AUTH/api/parse-cv'),
      );

      request.fields['user_id'] = userId ?? ''; // ⬅️ this is the fix
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
            errorMessage: "	Erreur d’analyse",
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
          errorMessage: "Échec analyse du CV. Réessayez.",
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> showIncompleteFieldsDialog(
      BuildContext context, List<String> fields) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color.fromARGB(255, 27, 27, 27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          constraints: const BoxConstraints(minHeight: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1.5, // Increase the scale factor as needed
                child: Lottie.asset(
                  warningicon,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "	Champs incomplets",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Complétez les champs suivants:\n\n${fields.join(', ')}",
                style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                        color: Color(0xFF00C2C2),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text("OK",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showMissingFieldsDialog(
      BuildContext context, Set<String> fields) async {
    final String formattedFields = missingFields.map((f) => "• $f").join('\n');

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color.fromARGB(255, 27, 27, 27),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            constraints: const BoxConstraints(minHeight: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFC107), size: 40),
                const SizedBox(height: 20),
                const Text(
                  "	CV incomplet",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Remplissez ces champs avant de sauvegarder:\n\n$formattedFields",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFCCCCCC),
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
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
                      "OK",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

    return parts.isEmpty ? 'Aucune dispo choisie' : parts.join("  •  ");
  }

  @override
  void initState() {
    super.initState();
    selectedLanguages = {};
    resumeController = TextEditingController();
    fetchUserId();
    fetchUserData();
    fetchEmployeeData();
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

  bool _showAllInterests = false;
  void _openEditEducationSheet() async {
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditEducationSheet(
        onSave: (newList) {
          Navigator.pop(context, newList);
        },
        educations: educations,
      ),
    );
    if (updated != null) {
      setState(() {
        educations = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

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
                          'Postuler',
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
                        'CV ou Résumé',
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
                                "Importez votre CV puis utilisez-le pour vos candidatures",
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
                                      "Erreur lors de l'envoi",
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
                                        'Importer',
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
                        'Mes langues',
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
                      builder: (_) => // From parent:
                          LanguageDetailsSheet(
                        initialSelection: selectedLanguages,
                        onSelectionChanged: (newSet) {
                          setState(() {
                            selectedLanguages = newSet;
                          });
                        },
                      ),
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
                                    ? 'Aucune langue'
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
                    ), //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
                        'Résumé',
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
                              'Expérience',
                              style: TextStyle(
                                color: white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => EditExperienceSheet(
                                    initialExperiences: experiences,
                                    onSave: (updated) =>
                                        setState(() => experiences = updated),
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

                        // 🔽 Read More / 🔼 Read Less toggle
                        if (experiences.length > 3)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showAll = !showAll;
                              });
                            },
                            child: Text(
                              showAll ? 'Voir moins' : 'Voir plus',
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
                  showAll: _showAllEdu,
                  onToggleShowAll: () =>
                      setState(() => _showAllEdu = !_showAllEdu),
                  onEdit: () async {
                    final updated = await showModalBottomSheet<List<String>>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EditEducationSheet(
                        educations: educations,
                        onSave: (_) {}, // not used anymore
                      ),
                    );

                    if (updated != null) {
                      setState(() {
                        educations = updated;
                      });
                    }
                  },
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
                        showAll: _showAllInterests,
                        onToggleShowAll: () => setState(
                            () => _showAllInterests = !_showAllInterests),
                        onEdit: _openEditInterestsSheet,
                      ),

                      const SizedBox(height: 25),

                      // Soft Skills chips + edit
                      Container(
                        decoration: BoxDecoration(
                          color: blue_gray,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text(
                                'Soft Skills',
                                style: TextStyle(
                                    color: white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _openEditSoftSkillsSheet,
                                child: const Icon(Icons.edit,
                                    color: white_gray, size: 20),
                              ),
                            ]),
                            const SizedBox(height: 15),
                            if (softSkills.isEmpty)
                              const Text(
                                'Aucune compétence douce',
                                style:
                                    TextStyle(color: white_gray, fontSize: 15),
                              )
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: softSkills.map((skill) {
                                  return Container(
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
                                          color: white, fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      const SizedBox(height: 15),
                      SkillsSection(skills: skills), const SizedBox(height: 15),
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
                                  'Certificats',
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
                                'Aucun certificat ajouté',
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
                                                cert['title'] ?? 'Sans titre',
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
                                                      'Vérifié',
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
                                          cert['issuer'] ?? 'Émetteur inconnu',
                                          style: const TextStyle(
                                              color: white_gray, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cert['date'] ?? 'Sans date',
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
                                        '	Ajouter un certificat',
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
                  final Set<String> incompleteFields = {};

                  incompleteFields.clear();

                  if (selectedLanguages.isEmpty)
                    incompleteFields.add("Langues");
                  if ((resumeController?.text.trim().isEmpty ?? true))
                    incompleteFields.add("Résumé");
                  if (experiences.isEmpty) incompleteFields.add("Expérience");
                  if (educations.isEmpty) incompleteFields.add("Formation");
                  if (selectedInterests.isEmpty)
                    incompleteFields.add("Intérêts");
                  if (softSkills.isEmpty)
                    incompleteFields.add("Compétences douces");
                  if ((phone?.trim().isEmpty ?? true))
                    incompleteFields.add("N° de téléphone");
                  if ((address?.trim().isEmpty ?? true))
                    incompleteFields.add("Adresse");

                  if (incompleteFields.isNotEmpty) {
                    await showIncompleteFieldsDialog(
                        context, incompleteFields.toList());
                    return;
                  }
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
                      'Enregistrer',
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
                  'Certificats',
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
                'Aucun certificat ajouté',
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
                                cert['title'] ?? 'Sans titre',
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
                                      'Vérifié',
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
                          cert['issuer'] ?? 'Émetteur inconnu',
                          style:
                              const TextStyle(color: white_gray, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cert['date'] ?? 'Sans date',
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
                'Ajouter un certificat',
                style: TextStyle(
                    color: white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              _buildTextField(_titleController, 'Titre du certificat'),
              const SizedBox(height: 12),
              _buildTextField(_issuerController, 'Émetteur (ex. Coursera)'),
              const SizedBox(height: 12),
              _buildTextField(_dateController, 'Date (facultatif)',
                  hint: '2024'),
              const SizedBox(height: 12),
              _buildTextField(_tagController, 'Tag (facultatif)',
                  hint: 'ex. UI/UX'),
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
                            : 'Importer PDF/Image',
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
                  'Certificat vérifié (Coursera, Google etc)',
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
                child: const Text('	Ajouter certificat',
                    style: TextStyle(
                        color: white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 25),
              const Text(
                'Certificats ajoutés',
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
                            tooltip: 'Supprimer certificat',
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
                      'Enregistrer tout',
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
                'Modifier vos compétences',
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
                        hintText: 'Nouvelle compétence',
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
                      'Enregistrer',
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
    if (level <= 0.33) return "Débutant";
    if (level <= 0.66) return "Intermédiaire";
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
                'Compétences & maîtrise',
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
            'Mettez en avant vos atouts, montrez aux recruteurs vos points forts !',
            style: TextStyle(color: white_gray, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Displaying Skills
          if (skills.isEmpty)
            const Text(
              'Aucune compétence ajoutée.',
              style: TextStyle(color: white_gray, fontSize: 15),
            )
          else
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
                      Flexible(
                        child: Text(
                          skill['name'],
                          style: const TextStyle(
                            color: black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
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
              Text('Débutant', style: TextStyle(color: white)),
              Text('Intermédiaire', style: TextStyle(color: white_gray)),
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
                      'Ajouter une compétence',
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
  final ValueChanged<List<String>> onSave;

  const EditSoftSkillsSheet({
    Key? key,
    required this.initialSoftSkills,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditSoftSkillsSheetState createState() => _EditSoftSkillsSheetState();
}

class _EditSoftSkillsSheetState extends State<EditSoftSkillsSheet> {
  late Set<String> _selected;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSoftSkills);
  }

  void _toggle(String skill) {
    setState(() {
      if (_selected.contains(skill))
        _selected.remove(skill);
      else
        _selected.add(skill);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allSoftSkills
        .where((s) => s.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();

    return WillPopScope(
      onWillPop: () async {
        widget.onSave(_selected.toList());
        return true;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (_, scroll) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: blue_gray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // handle
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
                'Sélectionnez vos Soft Skills',
                style: TextStyle(
                    color: white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // search
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
                      child: TextField(
                        style: const TextStyle(color: white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Rechercher une compétence douce…',
                          hintStyle: TextStyle(color: white_gray),
                        ),
                        onChanged: (v) => setState(() => _searchText = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // chips list
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: filtered.map((skill) {
                      final sel = _selected.contains(skill);
                      return GestureDetector(
                        onTap: () => _toggle(skill),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? blue : black_gray,
                            borderRadius: BorderRadius.circular(100),
                            border: sel ? null : Border.all(color: white_gray),
                          ),
                          child: Text(
                            skill,
                            style: TextStyle(
                                color: sel ? black : white_gray,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  widget.onSave(_selected.toList());
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Center(
                    child: Text(
                      'Enregistrer',
                      style: TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
              // Save
            ],
          ),
        ),
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
    isImmediate = widget.initialValue == 'Immédiatement';
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
                'Quand pouvez-vous commencer à travailler ?',
                style: TextStyle(
                    color: white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                activeColor: blue,
                value: isImmediate,
                onChanged: (val) => setState(() => isImmediate = val),
                title: const Text(
                  'Immédiatement',
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
                              : 'Sélectionner la date de début',
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
                      ? 'Immédiatement'
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
                      'Enregistrer',
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
  'Communication',
  'Teamwork',
  'Adaptability',
  'Problem-solving',
  'Critical thinking',
  'Time management',
  'Work ethic',
  'Creativity',
  'Emotional intelligence',
  'Leadership',
  'Responsibility',
  'Decision making',
  'Conflict resolution',
  'Flexibility',
  'Organization',
  'Empathy',
  'Collaboration',
  'Stress management',
  'Multitasking',
  'Self-motivation',
  'Listening',
  'Accountability',
  'Persuasion',
  'Negotiation',
  'Patience',
  'Confidence',
  'Delegation',
  'Initiative',
  'Attention to detail',
  'Public speaking',
  'Positive attitude',
  'Active learning',
  'Strategic thinking',
  'Constructive feedback',
  'Giving feedback',
  'Coaching',
  'Mentoring',
  'Discipline',
  'Cultural awareness',
  'Resourcefulness',
  'Integrity',
  'Goal-setting',
  'Self-awareness',
  'Curiosity',
  'Non-verbal communication',
  'Humility',
  'Respectfulness',
  'Inclusivity',
  'Receptiveness',
  'Mindfulness',
  'Self-regulation',
  'Stress tolerance',
  'Analytical skills',
  'Digital literacy',
  'Networking',
  'Facilitation',
  'Service orientation',
  'Relationship building',
  'Diplomacy',
  'Assertiveness',
  'Boundary setting',
  'Change management',
  'Persuasive writing',
  'Storytelling',
  'Visioning',
  'Influencing',
  'Crisis management',
  'Customer empathy',
  'Ethical judgment',
  'Risk assessment',
  'Process improvement',
  'Quality orientation',
  'Global mindset',
  'Social responsibility',
  'Data-driven decision making',
  'Resilience',
  'Tolerance for ambiguity',
  'Systems thinking',
  'Design thinking',
  'Problem identification',
];

class AvailabilitySection extends StatefulWidget {
  const AvailabilitySection({super.key});

  @override
  State<AvailabilitySection> createState() => _AvailabilitySectionState();
}

class _AvailabilitySectionState extends State<AvailabilitySection> {
  String startDateText = 'Immédiatement';

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
                  'Disponibilité',
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
                    text: 'Date de début: ',
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
              'Disponibilité hebdomadaire',
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
                      label: 'Matin',
                      selected: selected.contains('Matin'),
                      onTap: () => toggle(day, 'Matin'),
                    ),
                    const SizedBox(width: 10),
                    ToggleChip(
                      label: 'Soir',
                      selected: selected.contains('Soir'),
                      onTap: () => toggle(day, 'Soir'),
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
  final List<String> initialInterests;
  final ValueChanged<List<String>> onSave;

  const EditInterestsSheet({
    super.key,
    required this.initialInterests,
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
    controllers = widget.initialInterests
        .map((i) => TextEditingController(text: i))
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
                'Modifier vos centres d’intérêt',
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
                            hintText: 'Intérêt ${index + 1}',
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
                  'Ajouter un intérêt',
                  style: TextStyle(color: blue),
                ),
              ),

              const SizedBox(height: 20),

              // 🔍 Preview
              if (controllers.any((c) => c.text.trim().isNotEmpty)) ...[
                const Text(
                  'Aperçu:',
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
                      .where((s) => s.isNotEmpty)
                      .toList();
                  widget.onSave(updated);
                },
                child: const Text(
                  'Enregistrer',
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
      label == 'Matin' ? Icons.wb_sunny_rounded : Icons.nightlight_round;

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

class EditExperienceSheet extends StatefulWidget {
  final List<String> initialExperiences;
  final ValueChanged<List<String>> onSave;

  const EditExperienceSheet({
    Key? key,
    required this.initialExperiences,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditExperienceSheet> createState() => _EditExperienceSheetState();
}

class _EditExperienceSheetState extends State<EditExperienceSheet> {
  late List<TextEditingController> controllers;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers from passed-in experiences
    controllers = widget.initialExperiences
        .map((e) => TextEditingController(text: e))
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

  void _addExperience() {
    setState(() {
      controllers.add(TextEditingController());
    });
    // Scroll to new field
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
      expand: false,
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
                'Modifier vos expériences',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Dynamic experience fields
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
                            hintText: 'Expérience ${index + 1}',
                            hintStyle: const TextStyle(color: white_gray),
                            filled: true,
                            fillColor: black_gray,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _removeExperience(index),
                        child: const Icon(Icons.delete, color: white_gray),
                      ),
                    ],
                  ),
                );
              }),

              // Add new
              TextButton.icon(
                onPressed: _addExperience,
                icon: const Icon(Icons.add, color: blue),
                label: const Text('Ajouter une expérience',
                    style: TextStyle(color: blue)),
              ),

              const SizedBox(height: 20),

              // Preview
              if (controllers.any((c) => c.text.trim().isNotEmpty)) ...[
                const Text(
                  'Aperçu :',
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
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, color: blue, size: 6),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.text.trim(),
                                    style: const TextStyle(
                                        color: white_gray, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // Save
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                child: const Text('Enregistrer',
                    style: TextStyle(
                        color: white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
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
String? fullName;
bool isCVIncomplete = false;
List<String> missingFields = [];
Map<String, dynamic>? weeklyAvailability;
String? availability;
String? sanitizeField(dynamic value) {
  if (value == null) return null;
  final str = value.toString().trim();
  if (str.isEmpty || str == '{}' || str == 'null') return null;
  return str;
}

// Future<void> fetchEmployeeData() async {
//   final prefs = await SharedPreferences.getInstance();
//   final userId = prefs.getString('user_id');

//   if (userId == null) {
//     print("❌ No user ID found");
//     return;
//   }

//   try {
//     final employeeResponse = await http.get(
//       Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'),
//     );

//     final userResponse = await http.get(
//       Uri.parse('$BASE_URL_AUTH/users/$userId'),
//     );

//     if (employeeResponse.statusCode == 200 &&
//         userResponse.statusCode == 200) {
//       final employeeData = jsonDecode(employeeResponse.body);
//       final userData = jsonDecode(userResponse.body);

//       setState(() {
//         fullName = sanitizeField(userData['full_name']);
//         resume = sanitizeField(employeeData['resume']);

//         experience = (employeeData['experience'] as List?)
//                 ?.map((e) => e.toString())
//                 .toList() ??
//             [];
//         education = (employeeData['education'] as List?)
//                 ?.map((e) => e.toString())
//                 .toList() ??
//             [];

//         languages = (employeeData['languages'] as List?)
//                 ?.map((e) => e.toString())
//                 .toList() ??
//             [];

//         interests = (employeeData['interests'] as List?)
//                 ?.map((e) => e.toString())
//                 .toList() ??
//             [];

//         softSkills = (employeeData['soft_skills'] as List?)
//                 ?.map((e) => e.toString())
//                 .toList() ??
//             [];

//         certificates = employeeData['certificates'] ?? [];
//         skillsAndProficiency = employeeData['skills_and_proficiency'] ?? [];

//         weeklyAvailability = employeeData['weekly_availability'];
//         availability = employeeData['availability'];
//       });

//       await CVChecker.updateCVStatus(employeeData);
//       final status = await CVChecker.isCVIncomplete();
//       final missing = await CVChecker.getMissingFields();

//       setState(() {
//         isCVIncomplete = status;
//         missingFields = missing;
//       });

//       print("✅ Employee and user data loaded successfully");
//     } else {
//       print(
//           "❌ Failed to fetch data: ${employeeResponse.body} | ${userResponse.body}");
//     }
//   } catch (e) {
//     print("❌ Error fetching profile data: $e");
//   }
// }

class ExpandingResumeField extends StatefulWidget {
  final TextEditingController controller;

  /// Optional initial resume text from your fetchUserCV()
  final String? initialResume;

  const ExpandingResumeField({
    super.key,
    required this.controller,
    this.initialResume,
  });

  @override
  State<ExpandingResumeField> createState() => _ExpandingResumeFieldState();
}

class _ExpandingResumeFieldState extends State<ExpandingResumeField> {
  final int maxChars = 700;
  final _focusNode = FocusNode();

  String? resume;
  // other fields...

  @override
  void initState() {
    super.initState();
    fetchEmployeeData(); // ← load resume + all CV fields
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> fetchEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    try {
      final empRes =
          await http.get(Uri.parse('$BASE_URL_AUTH/api/get-employee/$userId'));
      final usrRes = await http.get(Uri.parse('$BASE_URL_AUTH/users/$userId'));
      if (empRes.statusCode == 200 && usrRes.statusCode == 200) {
        final emp = jsonDecode(empRes.body);
        // final usr = jsonDecode(usrRes.body); // if you need fullName, etc.

        final fetchedResume = sanitizeField(emp['resume']);
        // parse other lists similarly...

        setState(() {
          resume = fetchedResume;
          widget.controller.text = resume ?? '';
          // e.g. experience = parseList(emp['experience']);
          // education = parseList(emp['education']);
          // languages = parseList(emp['languages']);
          // interests = parseList(emp['interests']);
          // softSkills = parseList(emp['soft_skills']);
          // certificates = emp['certificates'] ?? [];
          // skillsAndProficiency = emp['skills_and_proficiency'] ?? [];
          // availability = sanitizeField(emp['availability']);
          // weeklyAvailability = emp['weekly_availability'];
        });

        await CVChecker.updateCVStatus(emp);
        final status = await CVChecker.isCVIncomplete();
        final missing = await CVChecker.getMissingFields();
        setState(() {
          isCVIncomplete = status;
          missingFields = missing;
        });
      }
    } catch (e) {
      print("❌ Error fetching profile data: $e");
    }
  }

  String? sanitizeField(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '{}' || str == 'null') return null;
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = (resume ?? '').isEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: blue_gray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                maxLines: null,
                maxLength: maxChars,
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    const SizedBox.shrink(),
                style: const TextStyle(color: white_gray, fontSize: 15),
                cursorColor: white,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: isEmpty
                      ? 'Écrivez un court résumé ou une synthèse…'
                      : null,
                  hintStyle: const TextStyle(fontSize: 15, color: white_gray),
                ),
                onChanged: (_) => setState(() {
                  resume = widget.controller.text;
                }),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
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
                  '${maxChars - widget.controller.text.length} caractères restants',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageDetailsSheet extends StatefulWidget {
  final Set<String> initialSelection;
  final ValueChanged<Set<String>> onSelectionChanged;

  const LanguageDetailsSheet({
    Key? key,
    required this.initialSelection,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<LanguageDetailsSheet> createState() => _LanguageDetailsSheetState();
}

class _LanguageDetailsSheetState extends State<LanguageDetailsSheet> {
  String _searchText = '';
  late Set<String> localSelection;

  @override
  void initState() {
    super.initState();
    // Initialize with passed-in selection
    localSelection = {...widget.initialSelection};
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allLanguages
        .where((lang) => lang.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();

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
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Cancel button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: white_gray),
                  ),
                  const Spacer(),
                  // Confirm button
                  GestureDetector(
                    onTap: () {
                      widget.onSelectionChanged(localSelection);
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.check, color: white_gray),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Langues parlées',
                  style: TextStyle(
                      color: white, fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sélectionnez vos langues pour mettre à jour votre profil',
                style: TextStyle(color: white_gray, fontSize: 16),
              ),
              const SizedBox(height: 20),
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
                        onChanged: (value) =>
                            setState(() => _searchText = value),
                        style: const TextStyle(color: white, fontSize: 16),
                        cursorColor: white_gray,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Rechercher une langue',
                          hintStyle: TextStyle(color: white_gray, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: filtered.map((language) {
                  final selected = localSelection.contains(language);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected)
                          localSelection.remove(language);
                        else
                          localSelection.add(language);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? blue : blue_gray,
                        borderRadius: BorderRadius.circular(100),
                        border: selected
                            ? null
                            : Border.all(color: white_gray, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 6),
                      child: Text(
                        language,
                        style: TextStyle(
                            color: selected ? black : white_gray, fontSize: 15),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
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

  @override
  void didUpdateWidget(covariant ContactInfoSection old) {
    super.didUpdateWidget(old);
    if (old.phoneNumber != widget.phoneNumber ||
        old.address != widget.address) {
      setState(() {
        phone = widget.phoneNumber;
        address = widget.address;
      });
    }
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
                'Informations de contact',
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
          Text('Téléphone : $phone',
              style: const TextStyle(color: white_gray, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Adresse : $address',
              style: const TextStyle(color: white_gray, fontSize: 15)),
        ],
      ),
    );
  }
}
