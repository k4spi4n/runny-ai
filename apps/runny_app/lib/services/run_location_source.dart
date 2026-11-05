import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/recorded_run.dart';

class RunLocationSource {
  Future<bool> enabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> permission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  Future<LocationAccuracyStatus> accuracy() => Geolocator.getLocationAccuracy();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Stream<ServiceStatus> get serviceStatus =>
      Geolocator.getServiceStatusStream();

  Stream<RunFix> positions({required String title, required String text}) {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: title,
          notificationText: text,
          notificationChannelName: title,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map((p) => RunFix(p.latitude, p.longitude, p.timestamp, p.accuracy));
  }
}
