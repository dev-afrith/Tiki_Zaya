import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _prodBaseUrl = 'https://tiki-zaya-backend.onrender.com';
  static const String _debugBaseUrl = 'http://localhost:5001';

  static String get baseUrl => kDebugMode ? _debugBaseUrl : _prodBaseUrl;
}
