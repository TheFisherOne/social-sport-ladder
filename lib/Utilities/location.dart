import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../screens/ladder_config_page.dart';

String locationStatusString = 'Location Not Initialized';
String lastLocationStatus='';
class LocationService extends ChangeNotifier {
  Position? _lastLocation;
  DateTime? _lastUpdateTime;
  double _lastDistanceAway = 99999.0;
  bool _lastLocationOk = false;
  double _lastDistanceRefresh = 88888.0;
  Timer? _timer;

  bool isLastLocationOk() {
    return _lastLocationOk;
  }

  double getLastDistanceAway() {
    return _lastDistanceAway;
  }
  


  Future<void> updateLocation() async {
    Position? position;
    lastLocationStatus = '';
    try {
      // On web, it's good to be explicit about accuracy.
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 25,
        timeLimit: const Duration(seconds: 8),
      );

      position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);
    } catch (e) {
      if (e is TimeoutException) {
        lastLocationStatus = 'getCurrentPosition timed out, trying getLastKnownPosition';
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
          stopTimer();
        }
      }
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
      lastLocationStatus = 'Error getting location';
      if (kDebugMode) {
        print('Error getting location');
      }
    }
  }

  (Position?, int) getLast() {
    if (_lastUpdateTime == null) return (null, 9999);
    int seconds = DateTime.now().difference(_lastUpdateTime!).inSeconds;
    return (_lastLocation, seconds);
  }

  double measureDistance(
      double lat1, double lon1, double lat2, double lon2) {
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

    double distance = measureDistance(activeLadderDoc!.get('Latitude'),
        activeLadderDoc!.get('Longitude'), where.latitude, where.longitude);

    _lastDistanceAway = distance;
    return distance <= allowedDistance;
  }

Future<void> startTimer() async {

    stopTimer(); // Ensure no multiple timers are running
    // print('Starting location timer');
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
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

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      locationStatusString  = 'Location services are disabled.';
      if (kDebugMode) {
        print('Location services are disabled.');
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        locationStatusString  = 'Location permissions are denied';
        if (kDebugMode) {
          print('Location permissions are denied');
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      locationStatusString  = 'Location permissions are permanently denied, we cannot request permissions.';
      // Permissions are denied forever, handle appropriately.
      if (kDebugMode) {
        print('Location permissions are permanently denied, we cannot request permissions.');
      }
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    locationStatusString  = 'Location permissions are granted.';
    if (kDebugMode) {
      print('Location permissions are granted.');
    }
    await startTimer();
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
