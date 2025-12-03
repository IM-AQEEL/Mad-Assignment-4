import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _isTracking = false;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTracking => _isTracking;

  // Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Location services are disabled. Please enable them.';
      notifyListeners();
      return false;
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = 'Location permissions are denied';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _error = 'Location permissions are permanently denied';
      notifyListeners();
      return false;
    }

    return true;
  }

  // Get current location once
  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _error = 'Failed to get location: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Start continuous location tracking
  Future<void> startTracking() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    _isTracking = true;
    notifyListeners();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        _currentPosition = position;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Error tracking location: $e';
        notifyListeners();
      },
    );
  }

  // Stop location tracking
  void stopTracking() {
    _isTracking = false;
    notifyListeners();
  }

  // Calculate distance between two positions (in meters)
  double calculateDistance(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}