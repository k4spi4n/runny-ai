import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  String get _apiKey {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENWEATHER_API_KEY not found in .env');
    }
    return apiKey;
  }

  Future<WeatherSnapshot> fetchWeatherSnapshot({
    required double lat,
    required double lon,
  }) async {
    final weatherUri =
        Uri.https('api.openweathermap.org', '/data/2.5/weather', {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'appid': _apiKey,
          'units': 'metric',
          'lang': 'vi',
        });

    final aqiUri = Uri.https(
      'api.openweathermap.org',
      '/data/2.5/air_pollution',
      {'lat': lat.toString(), 'lon': lon.toString(), 'appid': _apiKey},
    );

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
    try {
      final aqiResponse = await http.get(aqiUri);
      if (aqiResponse.statusCode == 200) {
        final aqiBody = jsonDecode(aqiResponse.body) as Map<String, dynamic>;
        final list = (aqiBody['list'] as List?) ?? [];
        if (list.isNotEmpty) {
          final main =
              (list.first as Map<String, dynamic>)['main']
                  as Map<String, dynamic>?;
          aqi = main?['aqi'] as int?;
        }
      }
    } catch (e) {
      debugPrint('OpenWeather AQI error: $e');
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
