import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double latitude, double longitude});

enum LocationProblem { serviceOff, denied, deniedForever, failed }

/// The phone's approximate position, for "Near me". Permission is asked
/// for here, when someone taps Near me, and never at start-up. The position
/// is only used on the phone to measure distances; it isn't sent anywhere.
class DeviceLocation {
  const DeviceLocation();

  Future<({LatLng? position, LocationProblem? problem})> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) return (position: null, problem: LocationProblem.serviceOff);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return (position: null, problem: LocationProblem.denied);
    if (permission == LocationPermission.deniedForever) {
      return (position: null, problem: LocationProblem.deniedForever);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
      );
      return (position: (latitude: position.latitude, longitude: position.longitude), problem: null);
    } on Exception {
      // Mostly the time limit: no fix indoors or with location just switched on.
      return (position: null, problem: LocationProblem.failed);
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final deviceLocationProvider = Provider<DeviceLocation>((ref) => const DeviceLocation());
