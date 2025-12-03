import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/activity_model.dart';

class ActivityRepository {
  // Replace with your actual API URL
  static const String baseUrl = 'http://your-api-url.com/api'; // UPDATE THIS
  static const String activitiesEndpoint = '/activities';

  final Box _box = Hive.box('activities');
  static const int maxCachedActivities = 5;

  // Fetch all activities from API
  Future<List<Activity>> fetchActivities() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$activitiesEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final activities = data.map((json) => Activity.fromJson(json)).toList();

        // Cache recent activities
        await _cacheActivities(activities);

        return activities;
      } else {
        throw Exception('Failed to load activities: ${response.statusCode}');
      }
    } catch (e) {
      // If API fails, return cached activities
      return getCachedActivities();
    }
  }

  // Create new activity
  Future<Activity> createActivity(Activity activity, File? imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$activitiesEndpoint'),
      );

      // Add activity data
      request.fields['latitude'] = activity.latitude.toString();
      request.fields['longitude'] = activity.longitude.toString();
      request.fields['timestamp'] = activity.timestamp.toIso8601String();
      if (activity.description != null) {
        request.fields['description'] = activity.description!;
      }

      // Add image if available
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ));
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final createdActivity = Activity.fromJson(data);

        // Cache the new activity
        await _addToCache(createdActivity);

        return createdActivity;
      } else {
        throw Exception('Failed to create activity: ${response.statusCode}');
      }
    } catch (e) {
      // If API fails, save to cache with pending sync
      await _addToCache(activity);
      throw Exception('Failed to sync activity: $e');
    }
  }

  // Delete activity
  Future<void> deleteActivity(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$activitiesEndpoint/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete activity');
      }

      // Remove from cache
      await _removeFromCache(id);
    } catch (e) {
      throw Exception('Failed to delete activity: $e');
    }
  }

  // Get cached activities (recent 5)
  List<Activity> getCachedActivities() {
    try {
      final cachedData = _box.get('recent_activities', defaultValue: []);
      if (cachedData is List) {
        return cachedData
            .map((item) => Activity.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Cache activities (keep only recent 5)
  Future<void> _cacheActivities(List<Activity> activities) async {
    final recentActivities = activities.take(maxCachedActivities).toList();
    final jsonList = recentActivities.map((a) => a.toJson()).toList();
    await _box.put('recent_activities', jsonList);
  }

  // Add single activity to cache
  Future<void> _addToCache(Activity activity) async {
    List<Activity> cached = getCachedActivities();
    cached.insert(0, activity);

    if (cached.length > maxCachedActivities) {
      cached = cached.take(maxCachedActivities).toList();
    }

    final jsonList = cached.map((a) => a.toJson()).toList();
    await _box.put('recent_activities', jsonList);
  }

  // Remove activity from cache
  Future<void> _removeFromCache(String id) async {
    List<Activity> cached = getCachedActivities();
    cached.removeWhere((a) => a.id == id);

    final jsonList = cached.map((a) => a.toJson()).toList();
    await _box.put('recent_activities', jsonList);
  }

  // Clear all cache
  Future<void> clearCache() async {
    await _box.delete('recent_activities');
  }
}