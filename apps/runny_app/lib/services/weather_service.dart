import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
    return const Color(0xFF7E0023); // Maroon/Dark Red
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

  String get _openWeatherApiKey {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENWEATHER_API_KEY not found in .env');
    }
    return apiKey;
  }

  String? get _waqiApiKey {
    return dotenv.env['WAQI_API_KEY'];
  }

  Future<WeatherSnapshot> fetchWeatherSnapshot({
    required double lat,
    required double lon,
  }) async {
    final weatherUri =
        Uri.https('api.openweathermap.org', '/data/2.5/weather', {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'appid': _openWeatherApiKey,
          'units': 'metric',
          'lang': 'vi',
        });

    final weatherResponse = await http.get(weatherUri);
    if (weatherResponse.statusCode != 200) {
      debugPrint('OpenWeather weather error: ${weatherResponse.statusCode}');
      throw Exception('Failed to fetch weather');
    }

    final weatherBody =
        jsonDecode(weatherResponse.body) as Map<String, dynamic>;
    final weatherList = (weatherBody['weather'] as List?) ?? [];
    final weatherMain = weatherBody['main'] as Map<String, dynamic>?;
    final wind = weatherBody['wind'] as Map<String, dynamic>?;

    int? aqi;

    // Try WAQI first if key is available
    if (_waqiApiKey != null && _waqiApiKey!.isNotEmpty) {
      try {
        final waqiUri = Uri.parse(
          'https://api.waqi.info/feed/geo:$lat;$lon/?token=$_waqiApiKey',
        );
        final waqiResponse = await http.get(waqiUri);
        if (waqiResponse.statusCode == 200) {
          final waqiBody = jsonDecode(waqiResponse.body) as Map<String, dynamic>;
          if (waqiBody['status'] == 'ok') {
            aqi = waqiBody['data']['aqi'] as int?;
          }
        }
      } catch (e) {
        debugPrint('WAQI error: $e');
      }
    }

    // Fallback to OpenWeather AQI if WAQI failed or not available
    if (aqi == null) {
      try {
        final owmAirUri = Uri.https(
          'api.openweathermap.org',
          '/data/2.5/air_pollution',
          {
            'lat': lat.toString(),
            'lon': lon.toString(),
            'appid': _openWeatherApiKey,
          },
        );
        final owmAirResponse = await http.get(owmAirUri);
        if (owmAirResponse.statusCode == 200) {
          final owmAirBody =
              jsonDecode(owmAirResponse.body) as Map<String, dynamic>;
          final list = (owmAirBody['list'] as List?) ?? [];
          if (list.isNotEmpty) {
            final main =
                (list.first as Map<String, dynamic>)['main']
                    as Map<String, dynamic>?;
            final owmAqi = main?['aqi'] as int?;
            if (owmAqi != null) {
              // Map 1-5 to 0-500 scale roughly for consistency
              // 1: 0-50, 2: 51-100, 3: 101-150, 4: 151-200, 5: 201+
              aqi = owmAqi * 40; // Simple mapping: 1->40, 2->80, 3->120, 4->160, 5->200
            }
          }
        }
      } catch (e) {
        debugPrint('OpenWeather AQI error: $e');
      }
    }

    final weatherEntry = weatherList.isNotEmpty
        ? weatherList.first as Map<String, dynamic>
        : null;
    final description = weatherEntry?['description'] as String?;
    final icon = weatherEntry?['icon'] as String?;

    return WeatherSnapshot(
      fetchedAt: DateTime.now(),
      temperatureC: (weatherMain?['temp'] as num?)?.toDouble(),
      feelsLikeC: (weatherMain?['feels_like'] as num?)?.toDouble(),
      humidity: weatherMain?['humidity'] as int?,
      windKph: (wind?['speed'] as num?)?.toDouble() != null
          ? ((wind?['speed'] as num).toDouble() * 3.6)
          : null,
      description: description,
      icon: icon,
      aqi: aqi,
      locationName: weatherBody['name'] as String?,
    );
  }
}
