import 'dart:io';
import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../repository/activity_repository.dart';

class ActivityProvider with ChangeNotifier {
  final ActivityRepository _repository = ActivityRepository();

  List<Activity> _activities = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Activity> get activities {
    if (_searchQuery.isEmpty) {
      return _activities;
    }
    return _activities.where((activity) {
      final description = activity.description?.toLowerCase() ?? '';
      final location = activity.locationString.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return description.contains(query) || location.contains(query);
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // Fetch activities from API
  Future<void> fetchActivities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _activities = await _repository.fetchActivities();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      // Load cached activities as fallback
      _activities = _repository.getCachedActivities();
      notifyListeners();
    }
  }

  // Create new activity
  Future<bool> createActivity({
    required double latitude,
    required double longitude,
    File? imageFile,
    String? description,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newActivity = Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        description: description,
      );

      final createdActivity = await _repository.createActivity(
        newActivity,
        imageFile,
      );

      _activities.insert(0, createdActivity);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete activity
  Future<bool> deleteActivity(String id) async {
    try {
      await _repository.deleteActivity(id);
      _activities.removeWhere((activity) => activity.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Clear search
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // Get cached activities (offline mode)
  void loadCachedActivities() {
    _activities = _repository.getCachedActivities();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}