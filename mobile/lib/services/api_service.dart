import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart' as dio;
import '../config/api_config.dart';

class ApiService {
  static String get socketBaseUrl => ApiConfig.baseUrl;

  static final _dio = dio.Dio(dio.BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Get stored token (now fetches latest from Firebase if available)
  static Future<String?> getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Store token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Store user data
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  // Get stored user data
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return _standardizeUser(jsonDecode(userStr));
    }
    return null;
  }

  // Standardize user object ID
  static Map<String, dynamic> _standardizeUser(Map<String, dynamic> user) {
    if (user.containsKey('_id') && !user.containsKey('id')) {
      user['id'] = user['_id'];
    } else if (user.containsKey('id') && !user.containsKey('_id')) {
      user['_id'] = user['id'];
    }
    return user;
  }

  // Clear session
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Check if logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // ─── AUTH ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyOTP(String email, String otp) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resendOTP(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/resend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (data.containsKey('user')) {
      data['user'] = _standardizeUser(data['user']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String otp, String newPassword) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );
    return jsonDecode(response.body);
  }

  // ─── VIDEOS ───────────────────────────────────────────

  static Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 10}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/feed?page=$page&limit=$limit'),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getUserVideos(String userId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/user/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> uploadVideo(
      XFile videoFile, String caption) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/videos/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['caption'] = caption;

    if (kIsWeb) {
      final bytes = await videoFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'video',
        bytes,
        filename: videoFile.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> uploadVideoWithProgress({
    required XFile videoFile,
    required String caption,
    required int videoDurationSeconds,
    String? thumbnailUrl,
    Map<String, dynamic>? editingMetadata,
    Function(double)? onProgress,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/videos/upload').toString();

    // Parse hashtags and mentions
    final hashtags = RegExp(r'#(\w+)').allMatches(caption).map((m) => m.group(1)!).toList();
    final mentions = RegExp(r'@(\w+)').allMatches(caption).map((m) => m.group(1)!).toList();

    dio.MultipartFile file;
    if (kIsWeb) {
      final bytes = await videoFile.readAsBytes();
      file = dio.MultipartFile.fromBytes(
        bytes,
        filename: videoFile.name.isNotEmpty ? videoFile.name : 'video.mp4',
      );
    } else {
      file = await dio.MultipartFile.fromFile(
        videoFile.path,
        filename: videoFile.name,
      );
    }

    final formData = dio.FormData.fromMap({
      'caption': caption,
      'videoDurationSeconds': videoDurationSeconds,
      'hashtags': hashtags,
      'mentions': mentions,
      'thumbnailUrl': thumbnailUrl ?? '',
      'editingMetadata': editingMetadata != null ? jsonEncode(editingMetadata) : null,
      'video': file,
    });

    try {
      final response = await _dio.post(
        url,
        data: formData,
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );
      return response.data;
    } catch (e) {
      if (e is dio.DioException) {
        return {'error': e.message, 'data': e.response?.data};
      }
      return {'error': e.toString()};
    }
  }

  // ─── MESSAGES ────────────────────────────────────────

  static Future<Map<String, dynamic>> getInboxData() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/inbox'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (data is List) {
      return {'inbox': data, 'unreadTotal': 0};
    }
    return data;
  }

  static Future<List<dynamic>> getInbox() async {
    final data = await getInboxData();
    return (data['inbox'] as List?) ?? [];
  }

  static Future<List<dynamic>> getConversation(String userId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/$userId'),
      headers: {'Authorization': 'Bearer $token'},

    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> sendMessage(
    String userId,
    String text, {
    String messageType = 'text',
    Map<String, dynamic>? sharedVideo,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'text': text,
        'messageType': messageType,
        if (sharedVideo != null) 'sharedVideo': sharedVideo,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUnreadMessagesCount() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/unread-count'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<void> markConversationRead(String userId) async {
    final token = await getToken();
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/read/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  static Future<Map<String, dynamic>> toggleLike(String videoId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/like/$videoId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> toggleFavorite(String videoId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/favorite/$videoId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<void> incrementVideoView(String videoId) async {
    try {
      await http.put(Uri.parse('${ApiConfig.baseUrl}/api/videos/view/$videoId'));
    } catch (_) {
      // Slient fail for views
    }
  }

  static Future<Map<String, dynamic>> incrementVideoShare(String videoId) async {
    final response = await http.put(Uri.parse('${ApiConfig.baseUrl}/api/videos/share/$videoId'));
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getVideoStats(String videoId) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/videos/stats/$videoId'));
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getVideoById(String videoId) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/videos/single/$videoId'));
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> archiveVideo(String videoId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/archive/$videoId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> unarchiveVideo(String videoId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/unarchive/$videoId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getArchivedVideos() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/archived/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteVideo(String videoId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/videos/$videoId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>?> getDiscoveryData() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/videos/discovery'));
      return jsonDecode(response.body);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> searchHashtagsAndVideos(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/videos/search?query=${Uri.encodeComponent(query)}'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'hashtags': [], 'videos': []};
    }
  }

  // ─── COMMENTS ─────────────────────────────────────────

  static Future<List<dynamic>> getComments(String videoId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/comments/$videoId'),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addCommentReply(
      String videoId, String text, String parentCommentId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/comments/$videoId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'text': text,
        'parentCommentId': parentCommentId,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> toggleCommentLike(String commentId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/comments/like/$commentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteComment(String commentId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/comments/$commentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addComment(
      String videoId, String text) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/comments/$videoId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'text': text}),
    );
    return jsonDecode(response.body);
  }

  // ─── USER PROFILE ─────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId'),
    );
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      return _standardizeUser(data);
    }
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/users/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return _standardizeUser(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> uploadProfileImage(XFile imageFile) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/users/upload-profile-pic'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    if (kIsWeb) {
      final bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'profile.jpg',
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> toggleFollow(String userId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/users/follow/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> togglePrivacy() async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/users/privacy'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/users/delete-account'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getSuggestedUsers() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/users/suggested'));
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<void> markAllNotificationsRead() async {
    final token = await getToken();
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/read-all'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  static Future<List<dynamic>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/search?q=$query'),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> toggleRepost(String videoId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/users/repost/$videoId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getUserReposts(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/reposts'),
    );
    return jsonDecode(response.body);
  }
}

