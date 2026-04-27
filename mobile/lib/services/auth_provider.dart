import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    await checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (loggedIn) {
        final userData = await ApiService.getUser();
        if (userData != null) {
          _user = userData;
          _isAuthenticated = true;
          
          // Refresh user data in background
          _refreshUserData();
        } else {
          _isAuthenticated = false;
        }
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final summary = await ApiService.getGamificationSummary();
      final profile = summary['user'] as Map<String, dynamic>?;
      if (profile != null && profile.isNotEmpty) {
        _user = profile;
        await ApiService.saveUser(profile);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> login(Map<String, dynamic> sessionData) async {
    await ApiService.saveSession(sessionData);
    _user = sessionData['user'] as Map<String, dynamic>?;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> updatedData) async {
    if (_user != null) {
      _user = {..._user!, ...updatedData};
      await ApiService.saveUser(_user!);
      notifyListeners();
    }
  }
}
