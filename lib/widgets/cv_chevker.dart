import 'package:shared_preferences/shared_preferences.dart';

class CVChecker {
  static Future<bool> isCVIncomplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("cv_status") == "cv incomplete";
  }

  static Future<List<String>> getMissingFields() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList("cv_missing_fields") ?? [];
  }

  static Future<void> updateCVStatus(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> missingFields = [];

    if ((data['resume'] ?? '').toString().trim().isEmpty) {
      missingFields.add("resume");
    }

    if ((data['education'] as List?)?.isEmpty ?? true) {
      missingFields.add("education");
    }

    if ((data['languages'] as List?)?.isEmpty ?? true) {
      missingFields.add("languages");
    }

    if ((data['soft_skills'] as List?)?.isEmpty ?? true) {
      missingFields.add("soft skills");
    }

    if ((data['availability'] ?? '').toString().trim().isEmpty) {
      missingFields.add("availability");
    }

    if ((data['weekly_availability'] ?? {}).toString().trim().isEmpty) {
      missingFields.add("weekly availability");
    }

    if ((data["available_start_date"] ?? '').toString().trim().isEmpty) {
      missingFields.add("start date availability");
    }

    if (missingFields.isNotEmpty) {
      await prefs.setString("cv_status", "cv incomplete");
      await prefs.setStringList("cv_missing_fields", missingFields);
    } else {
      await prefs.setString("cv_status", "cv complete");
      await prefs.remove("cv_missing_fields");
    }
  }
}
