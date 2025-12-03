class Activity {
  final String id;
  final double latitude;
  final double longitude;
  final String? imagePath;
  final String? imageUrl;
  final DateTime timestamp;
  final String? description;

  Activity({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.imagePath,
    this.imageUrl,
    required this.timestamp,
    this.description,
  });

  // Convert Activity to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }

  // Create Activity from JSON
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? json['_id'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      imagePath: json['imagePath'],
      imageUrl: json['imageUrl'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      description: json['description'],
    );
  }

  // Create a copy with updated fields
  Activity copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? imagePath,
    String? imageUrl,
    DateTime? timestamp,
    String? description,
  }) {
    return Activity(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
    );
  }

  String get locationString => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}