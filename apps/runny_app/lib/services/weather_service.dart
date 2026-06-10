import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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

  bool get _shouldUseProxy =>
      kIsWeb ||
      dotenv.env['OPENWEATHER_API_KEY'] == null ||
      dotenv.env['OPENWEATHER_API_KEY']!.isEmpty;

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
    // Luôn thử qua Proxy trước nếu đang ở môi trường Web hoặc thiếu Key trực tiếp
    if (_shouldUseProxy) {
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'weather',
          body: {'lat': lat, 'lon': lon},
          method: HttpMethod.post,
        );

        if (response.status == 200 && response.data != null) {
          return _parseProxyResponse(response.data!);
        }
        
        // Nếu không phải 200, ném lỗi để nhảy vào catch và thử fallback trực tiếp
        throw Exception('Proxy status: ${response.status}');
      } catch (e) {
        debugPrint('Weather proxy failed ($e). Attempting direct fallback...');
        // Tiếp tục xuống phần gọi trực tiếp bên dưới nếu proxy lỗi
      }
    }

    // PHẦN GỌI TRỰC TIẾP (FALLBACK HOẶC DEFAULT)
    return _fetchDirectly(lat: lat, lon: lon);
  }

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

    final weatherBody = body['weather'] as Map<String, dynamic>?;
    final waqiBody = body['waqi'] as Map<String, dynamic>?;
    final owmAirBody = body['owm_aqi'] as Map<String, dynamic>?;

    final weatherList = (weatherBody?['weather'] as List?) ?? [];
    final weatherMain = weatherBody?['main'] as Map<String, dynamic>?;
    final wind = weatherBody?['wind'] as Map<String, dynamic>?;

    int? aqi;
    double? temp = (weatherMain?['temp'] as num?)?.toDouble();
    int? humidity = weatherMain?['humidity'] as int?;
    double? windKph = (wind?['speed'] as num?)?.toDouble() != null
        ? ((wind?['speed'] as num).toDouble() * 3.6)
        : null;
    String? locationName = weatherBody?['name'] as String?;

    final weatherEntry = weatherList.isNotEmpty
        ? weatherList.first as Map<String, dynamic>
        : null;
    String? description = weatherEntry?['description'] as String?;
    String? icon = weatherEntry?['icon'] as String?;

    // Parse WAQI
    if (waqiBody != null && waqiBody['status'] == 'ok') {
      final data = waqiBody['data'] as Map<String, dynamic>;
      aqi = data['aqi'] as int?;

      if (temp == null ||
          humidity == null ||
          windKph == null ||
          locationName == null) {
        final iaqi = data['iaqi'] as Map<String, dynamic>?;
        temp ??= (iaqi?['t']?['v'] as num?)?.toDouble();
        humidity ??= (iaqi?['h']?['v'] as num?)?.toInt();
        final wValue = (iaqi?['w']?['v'] as num?)?.toDouble();
        if (wValue != null && windKph == null) {
          windKph = wValue * 3.6;
        }
        locationName ??= data['city']?['name'] as String?;
        description ??= 'Dữ liệu từ WAQI';
      }
    }

    // Fallback to OWM AQI
    if (aqi == null && owmAirBody != null) {
      final list = (owmAirBody['list'] as List?) ?? [];
      if (list.isNotEmpty) {
        final main =
            (list.first as Map<String, dynamic>)['main']
                as Map<String, dynamic>?;
        final owmAqi = main?['aqi'] as int?;
        if (owmAqi != null) {
          aqi = owmAqi * 40;
        }
      }
    }

    if (temp == null) {
      throw Exception('No temperature data available from Proxy');
    }

    return WeatherSnapshot(
      fetchedAt: DateTime.now(),
      temperatureC: temp,
      feelsLikeC: temp,
      humidity: humidity,
      windKph: windKph,
      description: description ?? 'Không có thông tin thời tiết',
      icon: icon,
      aqi: aqi,
      locationName: locationName ?? 'Vị trí không xác định',
    );
  }

  Future<WeatherSnapshot> _fetchDirectly({
    required double lat,
    required double lon,
  }) async {
    final hasOwm =
        dotenv.env['OPENWEATHER_API_KEY'] != null &&
        dotenv.env['OPENWEATHER_API_KEY']!.isNotEmpty;
    final hasWaqi = _waqiApiKey != null && _waqiApiKey!.isNotEmpty;

    if (!hasOwm && !hasWaqi) {
      throw Exception(
        'Neither OpenWeatherMap nor WAQI API keys are configured',
      );
    }

    int? aqi;
    double? temp;
    int? humidity;
    double? windKph;
    String? locationName;
    String? description;
    String? icon;

    if (hasOwm) {
      try {
        final weatherUri =
            Uri.https('api.openweathermap.org', '/data/2.5/weather', {
              'lat': lat.toString(),
              'lon': lon.toString(),
              'appid': _openWeatherApiKey,
              'units': 'metric',
              'lang': 'vi',
            });

        final weatherResponse = await http.get(weatherUri);
        if (weatherResponse.statusCode == 200) {
          final weatherBody =
              jsonDecode(weatherResponse.body) as Map<String, dynamic>;
          final weatherList = (weatherBody['weather'] as List?) ?? [];
          final weatherMain = weatherBody['main'] as Map<String, dynamic>?;
          final wind = weatherBody['wind'] as Map<String, dynamic>?;

          temp = (weatherMain?['temp'] as num?)?.toDouble();
          humidity = weatherMain?['humidity'] as int?;
          windKph = (wind?['speed'] as num?)?.toDouble() != null
              ? ((wind?['speed'] as num).toDouble() * 3.6)
              : null;
          locationName = weatherBody['name'] as String?;

          final weatherEntry = weatherList.isNotEmpty
              ? weatherList.first as Map<String, dynamic>
              : null;
          description = weatherEntry?['description'] as String?;
          icon = weatherEntry?['icon'] as String?;
        }
      } catch (e) {
        debugPrint('OpenWeatherMap direct call error: $e');
      }
    }

    if (hasWaqi) {
      try {
        final waqiUri = Uri.parse(
          'https://api.waqi.info/feed/geo:$lat;$lon/?token=$_waqiApiKey',
        );
        final waqiResponse = await http.get(waqiUri);
        if (waqiResponse.statusCode == 200) {
          final waqiBody =
              jsonDecode(waqiResponse.body) as Map<String, dynamic>;
          if (waqiBody['status'] == 'ok') {
            final data = waqiBody['data'] as Map<String, dynamic>;
            aqi = data['aqi'] as int?;

            if (temp == null ||
                humidity == null ||
                windKph == null ||
                locationName == null) {
              final iaqi = data['iaqi'] as Map<String, dynamic>?;
              temp ??= (iaqi?['t']?['v'] as num?)?.toDouble();
              humidity ??= (iaqi?['h']?['v'] as num?)?.toInt();
              final wValue = (iaqi?['w']?['v'] as num?)?.toDouble();
              if (wValue != null && windKph == null) {
                windKph = wValue * 3.6;
              }
              locationName ??= data['city']?['name'] as String?;
              description ??= 'Dữ liệu từ WAQI';
            }
          }
        }
      } catch (e) {
        debugPrint('WAQI direct call error: $e');
      }
    }

    if (aqi == null && hasOwm) {
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
              aqi = owmAqi * 40;
            }
          }
        }
      } catch (e) {
        debugPrint('OpenWeather AQI fallback error: $e');
      }
    }

    if (temp == null) {
      throw Exception('No temperature data available (Direct Fallback)');
    }

    return WeatherSnapshot(
      fetchedAt: DateTime.now(),
      temperatureC: temp,
      feelsLikeC: temp,
      humidity: humidity,
      windKph: windKph,
      description: description ?? 'Không có thông tin thời tiết',
      icon: icon,
      aqi: aqi,
      locationName: locationName ?? 'Vị trí không xác định',
    );
  }
}
