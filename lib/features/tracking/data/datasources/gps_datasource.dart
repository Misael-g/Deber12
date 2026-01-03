import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_point.dart';

/// DataSource para GPS usando plugin geolocator
abstract class GpsDataSource {
  Future<LocationPoint?> getCurrentLocation();
  Stream<LocationPoint> get locationStream;
  Future<bool> isGpsEnabled();
  Future<bool> requestPermissions();
  Future<void> openLocationSettings();
}

class GpsDataSourceImpl implements GpsDataSource {
  @override
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );


      return LocationPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        speed: pos.speed.toDouble(),
        accuracy: pos.accuracy.toDouble(),
        timestamp: pos.timestamp,
      );
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
      return null;
    }
  }

  @override
  Stream<LocationPoint> get locationStream {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );

    return Geolocator.getPositionStream(locationSettings: settings).map((pos) {
      return LocationPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        speed: pos.speed.toDouble(),
        accuracy: pos.accuracy.toDouble(),
        timestamp: pos.timestamp,
      );
    });
  }

  @override
  Future<bool> isGpsEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error solicitando permisos de ubicación: $e');
      return false;
    }
  }

  /// Abrir ajustes de ubicación (usado por la UI para invitar al usuario)
  @override
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error abriendo ajustes de ubicación: $e');
    }
  }
}
