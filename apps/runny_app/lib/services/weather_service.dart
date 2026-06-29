import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeatherSnapshot {
  final double? temperatureC;
  final double? feelsLikeC;
  final int? humidity;
  final double? windKph;
  final String? description;
  final String? icon;
  final int? aqi;
  final String? locationName;
  final DateTime fetchedAt;

  const WeatherSnapshot({
    required this.fetchedAt,
    this.temperatureC,
    this.feelsLikeC,
    this.humidity,
    this.windKph,
    this.description,
    this.icon,
    this.aqi,
    this.locationName,
  });

  String? get summary {
    if (description == null || description!.isEmpty) return null;
    return description![0].toUpperCase() + description!.substring(1);
  }

  String get aqiLabel {
    if (aqi == null) return 'Không rõ';
    if (aqi! <= 50) return 'Tốt';
    if (aqi! <= 100) return 'Trung bình';
    if (aqi! <= 150) return 'Kém';
    if (aqi! <= 200) return 'Xấu';
    if (aqi! <= 300) return 'Rất xấu';
    return 'Nguy hại';
  }

  Color get aqiColor {
    if (aqi == null) return Colors.grey;
    if (aqi! <= 50) return Colors.green;
    if (aqi! <= 100) return Colors.yellow;
    if (aqi! <= 150) return Colors.orange;
    if (aqi! <= 200) return Colors.red;
    if (aqi! <= 300) return Colors.purple;
    return const Color(0xFF7E0023);
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature_c': temperatureC,
      'feels_like_c': feelsLikeC,
      'humidity': humidity,
      'wind_kph': windKph,
      'description': description,
      'icon': icon,
      'aqi': aqi,
      'location_name': locationName,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      fetchedAt: DateTime.tryParse(json['fetched_at'] ?? '') ?? DateTime.now(),
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      feelsLikeC: (json['feels_like_c'] as num?)?.toDouble(),
      humidity: json['humidity'] as int?,
      windKph: (json['wind_kph'] as num?)?.toDouble(),
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      aqi: json['aqi'] as int?,
      locationName: json['location_name'] as String?,
    );
  }
}

class WeatherService {
  WeatherService();

  Future<WeatherSnapshot> fetchWeatherSnapshot({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'weather',
        body: {'lat': lat, 'lon': lon},
        method: HttpMethod.post,
      );

      if (response.status == 200 && response.data != null) {
        return _parseProxyResponse(response.data!);
      }
      
      throw Exception('Proxy status: ${response.status}');
    } catch (e) {
      debugPrint('Weather proxy failed ($e).');
      rethrow;
    }
  }

  // Proxy `weather` (Open-Meteo chính, WAQI dự phòng) trả về dữ liệu đã chuẩn hoá.
  WeatherSnapshot _parseProxyResponse(dynamic data) {
    final Map<String, dynamic> body;
    try {
      if (data is String) {
        body = Map<String, dynamic>.from(jsonDecode(data));
      } else if (data is Map) {
        body = Map<String, dynamic>.from(data);
      } else {
        throw Exception('Unexpected response format: ${data.runtimeType}');
      }
    } catch (e) {
      debugPrint('Error parsing weather proxy response: $e');
      throw Exception('Failed to parse weather data');
    }

    final temp = (body['temperature_c'] as num?)?.toDouble();
    if (temp == null) {
      throw Exception('No temperature data available from Proxy');
    }

    return WeatherSnapshot(
      fetchedAt: DateTime.now(),
      temperatureC: temp,
      feelsLikeC: (body['feels_like_c'] as num?)?.toDouble() ?? temp,
      humidity: (body['humidity'] as num?)?.toInt(),
      windKph: (body['wind_kph'] as num?)?.toDouble(),
      description: body['description'] as String? ?? 'Không có thông tin thời tiết',
      icon: body['icon'] as String?,
      aqi: (body['aqi'] as num?)?.toInt(),
      locationName: body['location_name'] as String? ?? 'Vị trí không xác định',
    );
  }
}
