import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipply/env.dart';
import 'package:swipply/pages/sign_in.dart';

class ApiService {
  static const String baseUrlAuth = BASE_URL_AUTH;
  static const String baseUrlJobs = BASE_URL_JOBS;

  static Future<http.Response> saveJob({
    required String userId,
    required String jobId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('$baseUrlJobs/api/save-job');
    return await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'user_id': userId, 'job_id': jobId}),
        )
        .timeout(Duration(seconds: 10));
  }

  static Future<dynamic> createUser(
    String email,
    String fullName,
    String phoneNumber,
    String password,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrlAuth/users'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "full_name": fullName,
            "phone_number": phoneNumber,
            "password": password,
          }),
        )
        .timeout(Duration(seconds: 10));
    return _handleResponse(response);
  }

  static Future<dynamic> signIn(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrlAuth/api/auth/login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(Duration(seconds: 10));

      if (response.headers['content-type']?.contains('application/json') ==
          true) {
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          return body;
        } else {
          return body['error'] ?? 'An unknown error occurred';
        }
      } else {
        return 'Une erreur est survenue. Veuillez réessayer.';
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<dynamic> signUp(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL_AUTH/api/signup'),
        body: {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return 'Échec de l’inscription. Veuillez réessayer.';
      }
    } catch (e) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    }
  }

  static Future<http.Response> removeSaveJob(
      {required String userId, required String jobId}) {
    final url = Uri.parse('$baseUrlJobs/api/save-job');
    return http
        .delete(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId, 'job_id': jobId}),
        )
        .timeout(const Duration(seconds: 10));
  }

  // helper to fetch all saved job IDs for current user:
  static Future<Set<String>> fetchSavedJobIds(String userId) async {
    final url = Uri.parse('$baseUrlJobs/api/saved-jobs?user_id=$userId');
    final resp = await http.get(url).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Failed to load saved jobs');
    final List data = jsonDecode(resp.body);
    return data.map<String>((j) => j['job_id'].toString()).toSet();
  }

  static Future<dynamic> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrlAuth/users'));
    return _handleResponse(response);
  }

  static Future<dynamic> updateUser(
    String userId,
    String fullName,
    String phoneNumber,
    bool hasVehicle,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrlAuth/users/$userId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "full_name": fullName,
        "phone_number": phoneNumber,
        "has_vehicle": hasVehicle,
      }),
    );
    return _handleResponse(response);
  }

  static const String fastApiUrl = 'https://swipply-2ue1.onrender.com';

  static Future<List<Map<String, dynamic>>> fetchBestJobsForUser({
    required String userId,
    int n = 100,
    List<String> excludeJobIds = const [],
    required String fastApiUrl, // e.g. https://your-fastapi
    required String baseUrlJobs, // e.g. https://your-node
    String? token,
  }) async {
    final bestUrl = '$fastApiUrl/find_best_jobs/$userId?n=$n';
    final bestRes =
        await http.get(Uri.parse(bestUrl)).timeout(const Duration(seconds: 30));
    if (bestRes.statusCode != 200) {
      throw Exception('best_jobs ${bestRes.statusCode}: ${bestRes.body}');
    }

    final best = jsonDecode(bestRes.body);
    final List bestJobs = (best['best_jobs'] as List?) ?? [];
    final ids = bestJobs
        .map<String>((j) => j['job_id'] as String)
        .where((id) => !excludeJobIds.contains(id))
        .toList();

    if (ids.isEmpty) return [];

    final out = <Map<String, dynamic>>[];
    const chunkSize = 40;

    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
          i, (i + chunkSize > ids.length) ? ids.length : i + chunkSize);

      // GET /api/jobs?ids=id1,id2,id3
      final uri = Uri.parse('$baseUrlJobs/api/jobs')
          .replace(queryParameters: {'ids': chunk.join(',')});

      final resp = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        throw Exception('job_details GET ${resp.statusCode}: ${resp.body}');
      }

      final List list = jsonDecode(resp.body);
      out.addAll(list.cast<Map<String, dynamic>>());
    }

    final byId = {for (final j in out) j['job_id']: j};
    return ids.map((id) => byId[id]).whereType<Map<String, dynamic>>().toList();
  }

  static Future<List<Map<String, dynamic>>> fetchJobs({
    List<String>? jobCategories,
    List<String>? categoryChips,
    String? employmentType,
    String? contractType,
    String? location,
    bool? canAutoApply,
    String? search,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final qp = <String, String>{};
    if (jobCategories != null && jobCategories.isNotEmpty) {
      qp['job_category'] = jobCategories.join(',');
    }
    if (categoryChips != null && categoryChips.isNotEmpty) {
      qp['category_chip'] = categoryChips.join(',');
    }
    if (employmentType != null) qp['employment_type'] = employmentType;
    if (contractType != null) qp['contract_type'] = contractType;
    if (location != null) qp['location'] = location;
    if (canAutoApply != null) qp['can_auto_apply'] = canAutoApply.toString();
    if (search != null && search.trim().isNotEmpty)
      qp['search'] = search.trim();

    final uri =
        Uri.parse('$BASE_URL_JOBS/api/jobs').replace(queryParameters: qp);
    final resp = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Failed to load jobs');
    }
  }

  static Future<void> signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      await http.post(
        Uri.parse('$baseUrlAuth/api/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }

    await prefs.remove('token');

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignIn()),
      (_) => false,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchFilteredJobs({
    List<String>? categories,
    List<String>? employmentTypes,
    List<String>? contractTypes,
    int? sinceHours,
    String? userId,
  }) async {
    final params = <String, String>{};
    if (categories != null && categories.isNotEmpty) {
      params['categories'] = categories.join(',');
    }
    if (employmentTypes != null && employmentTypes.isNotEmpty) {
      params['employment'] = employmentTypes.join(',');
    }
    if (contractTypes != null && contractTypes.isNotEmpty) {
      params['contract'] = contractTypes.join(',');
    }
    if (sinceHours != null) params['since_h'] = '$sinceHours';
    if (userId != null) params['user_id'] = userId;
    final uri =
        Uri.parse('$baseUrlJobs/api/jobs').replace(queryParameters: params);
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Fetch failed');
    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> fetchAllJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('$baseUrlJobs/api/jobs'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load jobs');
    }
  }

  static Future<dynamic> deleteUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.delete(
      Uri.parse('$baseUrlAuth/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Error: ${response.body}");
    }
  }
}

void testApiConnection() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('$BASE_URL_AUTH/users'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    print("Server Response: ${response.body}");
  } catch (e) {
    print("Connection Error: $e");
  }
}
