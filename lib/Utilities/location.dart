import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../screens/ladder_config_page.dart';
import 'location_button.dart';

String locationStatusString = 'Location Not Initialized';
String lastLocationStatus = '';
const double maxAcceptableAccuracyMeters = 200.0;

class LocationService extends ChangeNotifier {
  Position? _lastLocation;
  DateTime? _lastUpdateTime;
  double _lastDistanceAway = 99999.0;
  bool _lastLocationOk = false;
  double _lastDistanceRefresh = 88888.0;
  Timer? _timer;
  bool _permissionDenied = false;
  bool _permissionDeniedForever = false;

  bool get isPermissionDenied => _permissionDenied;
  bool get isPermissionDeniedForever => _permissionDeniedForever;

  bool isLastLocationOk() {
    return _lastLocationOk;
  }

  double getLastDistanceAway() {
    return _lastDistanceAway;
  }

  Future<void> updateLocation() async {
    Position? position;
    lastLocationStatus = '';

    // On web the Permissions API is unreliable (Safari reports prompt/denied
    // inaccurately), so just try getCurrentPosition, which prompts if needed.
    final LocationPermission permission = await Geolocator.checkPermission();
    if (!kIsWeb &&
        (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever)) {
      _permissionDenied = true;
      _permissionDeniedForever = permission == LocationPermission.deniedForever;
      lastLocationStatus = _permissionDeniedForever
          ? 'Location permission is permanently denied. Open app settings.'
          : 'Location permission is denied.';
      stopTimer();
      notifyListeners();
      return;
    }

    try {
      // On web, it's good to be explicit about accuracy.
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        timeLimit: const Duration(seconds: 15),
      );

      position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);
      if (_permissionDenied) {
        _permissionDenied = false;
        _permissionDeniedForever = false;
        locationStatusString = 'Location permissions are granted.';
        notifyListeners();
      }
    } catch (e) {
      if (e is TimeoutException) {
        lastLocationStatus =
            'getCurrentPosition timed out, trying getLastKnownPosition';
        if (kDebugMode) {
          print('getCurrentPosition timed out, trying getLastKnownPosition');
        }
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (e2) {
          lastLocationStatus = 'Error getting last known position: $e2';
          if (kDebugMode) {
            print('Error getting last known position: $e2');
          }
        }
      } else {
        if (kDebugMode) {
          print('Error updating location: $e');
        }
        if (e is PermissionDeniedException) {
          // Stop trying if permission is denied, to avoid spamming requests.
          _permissionDenied = true;
          lastLocationStatus = kIsWeb
              ? 'Location was denied. Allow location for this site in browser settings, then tap Retry.'
              : 'Location permission is denied.';
          stopTimer();
          notifyListeners();
        }
      }
    }

    if (position != null && position.accuracy > maxAcceptableAccuracyMeters) {
      lastLocationStatus =
          'Ignoring inaccurate location (+/-${position.accuracy.round()} m)';
      position = null;
    }

    if (position != null) {
      lastLocationStatus = '';
      _lastLocation = position;
      _lastUpdateTime = position.timestamp;

      bool newLocationOk = isLocationOk(_lastLocation!);
      if (newLocationOk != _lastLocationOk) {
        _lastLocationOk = newLocationOk;
        notifyListeners();
      }

      if ((_lastDistanceRefresh - _lastDistanceAway).abs() > 25.0) {
        _lastDistanceRefresh = _lastDistanceAway;
        notifyListeners();
      }
    } else {
      if (lastLocationStatus.isEmpty ||
          lastLocationStatus.startsWith('getCurrentPosition timed out')) {
        lastLocationStatus = 'Error getting location';
      }
      if (kDebugMode) {
        print(lastLocationStatus);
      }
    }
  }

  (Position?, int) getLast() {
    if (_lastUpdateTime == null) return (null, 9999);
    int seconds = DateTime.now().difference(_lastUpdateTime!).inSeconds;
    return (_lastLocation, seconds);
  }

  double measureDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0; // Radius of Earth in kilometers
    final double lat1Rad = lat1 * pi / 180.0;
    final double lon1Rad = lon1 * pi / 180.0;
    final double lat2Rad = lat2 * pi / 180.0;
    final double lon2Rad = lon2 * pi / 180.0;
    final double dLat = (lat2Rad - lat1Rad);
    final double dLon = lon2Rad - lon1Rad;
    final double a = pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c * 1000; // meters
  }

  bool isLocationOk(Position where) {
    double allowedDistance =
        (activeLadderDoc!.get('MetersFromLatLong') as num).toDouble();
    if (allowedDistance <= 0.0) return true; // location check disabled

    double distance = measureDistance(
        (activeLadderDoc!.get('Latitude') as num).toDouble(),
        (activeLadderDoc!.get('Longitude') as num).toDouble(),
        where.latitude,
        where.longitude);

    _lastDistanceAway = distance;
    return distance <= allowedDistance;
  }

  Future<void> startTimer() async {
    stopTimer(); // Ensure no multiple timers are running
    // print('Starting location timer');
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await updateLocation();
    });
    // Get initial location immediately
    await updateLocation();
  }

  void stopTimer() {
    // print('Stopping location timer');
    _timer?.cancel();
    _timer = null;
  }

  Future<void> init() async {
    bool serviceEnabled;
    LocationPermission permission;
    _permissionDenied = false;
    _permissionDeniedForever = false;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      locationStatusString = 'Location services are disabled.';
      if (kDebugMode) {
        print('Location services are disabled.');
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (kIsWeb && permission != LocationPermission.whileInUse) {
      // The web plugin reports any failure (timeout, unavailable, dismissed
      // prompt) as "denied forever", so probe with a real position request.
      try {
        await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(timeLimit: Duration(seconds: 20)));
        permission = LocationPermission.whileInUse;
      } on PermissionDeniedException {
        _permissionDenied = true;
        locationStatusString =
            'Location was denied. Allow location for this site in browser settings, then tap Retry.';
        notifyListeners();
        return;
      } catch (e) {
        // Timeout / position unavailable: not a permission problem, keep trying.
        permission = LocationPermission.whileInUse;
      }
    }
    if (permission == LocationPermission.denied) {
      _permissionDenied = true;
      if (locationButtonSupported) {
        // On Android the user grants location with the system location button.
        locationStatusString = 'Tap the location button to share your location';
        notifyListeners();
        return;
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        locationStatusString = 'Location permissions are temporarily denied';
        // if (kDebugMode) {
        //   print('Location permissions are denied');
        // }
        notifyListeners();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _permissionDenied = true;
      _permissionDeniedForever = true;
      locationStatusString =
          'Location permissions are permanently denied, we cannot request permissions.';
      // Permissions are denied forever, handle appropriately.
      if (kDebugMode) {
        print(
            'Location permissions are permanently denied, we cannot request permissions.');
      }
      notifyListeners();
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    locationStatusString = 'Location permissions are granted.';
    if (kDebugMode) {
      print('Location permissions are granted.');
    }
    notifyListeners();
    await startTimer();
  }

  Future<void> retryPermissionFlow() async {
    await init();
  }

  Future<bool> openAppSettingsForPermission() async {
    if (kIsWeb) {
      lastLocationStatus =
          'Browser location permissions are managed by your browser settings.';
      notifyListeners();
      return false;
    }
    return Geolocator.openAppSettings();
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
