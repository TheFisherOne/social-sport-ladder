import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../screens/ladder_config_page.dart';
import 'package:permission_handler/permission_handler.dart' as mobile_permissions;


class LocationService {
  Position? _lastLocation;
  DateTime? _lastUpdateTime;
  dynamic _pageToRefresh;
  double _lastDistanceAway=99999.0;
  bool _lastLocationOk = false;
  double _lastDistanceRefresh = 88888.0;
  bool isLastLocationOk(){
    return _lastLocationOk;
  }

  double getLastDistanceAway(){
    return _lastDistanceAway;
  }
  askForSetState(page){
    // print('ask for updates on Location ${page.toString()}');
    _pageToRefresh = page;
  }

 Future<bool> updateLocation() async {
    // save the time of the request not the result to prevent infinite loops
    LocationSettings locSettings = LocationSettings(distanceFilter: 25,);
    _lastLocation = await Geolocator.getCurrentPosition(locationSettings: locSettings);
    if (_lastLocation != null ){
      _lastUpdateTime = DateTime.now();
      // print('updateLocation: ${_lastLocation!.latitude}, ${_lastLocation!.longitude}');
    } else {
      if (kDebugMode) {
        print('updateLocation: got null');
      }
    }
    // print('got location $_lastLocation');
    bool newLocationOk = isLocationOk(_lastLocation!);
    if (newLocationOk != _lastLocationOk) {
      _lastLocationOk = newLocationOk;
      // print('Doing Location refresh of page');
      _pageToRefresh?.refresh();
      _pageToRefresh = null;
    }

    if ((_lastDistanceRefresh - _lastDistanceAway).abs() > 25.0){
      _lastDistanceRefresh = _lastDistanceAway;
      _pageToRefresh?.refresh();
    }
    return true;
  }

  (Position?, int) getLast(){
    if (_lastUpdateTime == null ) return (null, 9999);
    int seconds = DateTime.now().difference(_lastUpdateTime!).inSeconds;
    return (_lastLocation, seconds);
  }
  // double measureDistance(lat1, lon1, lat2, lon2) {
  //   // generally used geo measurement function
  //   var R = 6378.137; // Radius of earth in KM
  //   var dLat = lat2 * pi / 180 - lat1 * pi / 180;
  //   var dLon = lon2 * pi / 180 - lon1 * pi / 180;
  //   var a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  //   var c = 2 * atan2(sqrt(a), sqrt(1 - a));
  //   var d = R * c;
  //   print('a:$a c: $c d: $d dLat: $dLat dLon: $dLon');
  //   return d * 1000; // meters
  // }
  double measureDistance(double lat1, double lon1, double lat2, double lon2) {
    // Radius of Earth in kilometers
    const double R = 6371.0;

    // Convert degrees to radians
    final double lat1Rad = lat1 * pi / 180.0;
    final double lon1Rad = lon1 * pi / 180.0;
    final double lat2Rad = lat2 * pi / 180.0;
    final double lon2Rad = lon2 * pi / 180.0;

    // Haversine formula
    final double dLat = (lat2Rad - lat1Rad);
    final double dLon = lon2Rad - lon1Rad;
    final double a = pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Distance in kilometers then converted to meters
    return R * c * 1000;
  }
  bool isLocationOk( Position where) {
    double allowedDistance = (activeLadderDoc!.get('MetersFromLatLong') as num).toDouble();
    if (allowedDistance <= 0.0) return true; // this is disabled

    double distance = measureDistance(activeLadderDoc!.get('Latitude'), activeLadderDoc!.get('Longitude'), where.latitude, where.longitude);

    _lastDistanceAway = distance;
    if (distance > allowedDistance) {
      // print('isLocationOk: too far away $distance > $allowedDistance');
      return false;
    }
    // print('isLocationOK: location good $distance');
    return true;
  }

  Timer? _timer;
  startTimer() async {
    // print('start location timer');
    _timer?.cancel();
    _timer=null;
    _timer = Timer.periodic(Duration(seconds: 10), (_) async{

      // print('Location goes off $_pageToRefresh');
      if (_pageToRefresh != null) {
        await updateLocation();
      }
    });
    // print('created Location timer $_pageToRefresh');
    await updateLocation();
  }
  void stopTimer(){
    // print('stop location timer');
    _pageToRefresh = null;
    _timer?.cancel();
    _timer=null;
  }
  bool _notificationsEnabled = false;
  void init() async {
    bool canProceedWithLocation = false;
    if ((!kIsWeb)&&(Platform.isAndroid)) {
      // --- Step 1: Request Notification Permission (for Android 13+) ---
      // This is crucial because Geolocator's background service needs it.
      var notificationStatus = await mobile_permissions.Permission.notification.request();
      if (kDebugMode) {
        print('Notification permission status: $notificationStatus');
      }
      _notificationsEnabled = notificationStatus.isGranted;

      if (!_notificationsEnabled) {
        if (kDebugMode) {
          print('POST_NOTIFICATIONS permission not granted. Location services requiring foreground notification might fail or not start.');
        }
        // Decide how to handle this:
        // 1. Don't start location services that need the notification.
        // 2. Inform the user and guide them to grant permission.
        // For now, we'll prevent proceeding if notification perm is vital for the geolocator's foreground service.
        canProceedWithLocation = false;
      } else {
        canProceedWithLocation = true;
      }
    } else {
      // For non-Android platforms, or Android < 13 (where manifest permission is enough
      // and permission_handler might return .granted by default for .notification
      // if not applicable for runtime request)
      _notificationsEnabled = true; // Assume enabled or not needed for this specific issue
      canProceedWithLocation = true;
    }
    if (canProceedWithLocation) {
      bool locationServicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServicesEnabled) {
        if (kDebugMode) {
          print('Location services are disabled.');
        }
        // Optionally, prompt user to enable location services:
        // await Geolocator.openLocationSettings();
        // return; // Or handle appropriately
      }

      mobile_permissions.PermissionStatus locationPermissionStatus = await mobile_permissions.Permission.location.status; // Using permission_handler for consistency

      if (locationPermissionStatus.isDenied) {
        locationPermissionStatus = await mobile_permissions.Permission.location.request();
      }

      if (locationPermissionStatus.isGranted) {
        if (kDebugMode) {
          print('Location permission granted.');
        }
        // --- Step 3: Start your location-dependent operations ---
        startTimer(); // Now it's safer to call this
      } else {
        if (kDebugMode) {
          print('Location permission denied. Cannot start timer.');
        }
        // Handle location permission denial
      }
    } else {
      if (kDebugMode) {
        print('Cannot proceed with location services due to missing notification permission.');
      }
      // Handle the case where notification permission (required for foreground service) was not granted.
    }

    await Geolocator.isLocationServiceEnabled();
// Note: requestService() isn’t needed on web; skip or handle via permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    startTimer();

 }
  void dispose() {
    // print('dispose of location timer');
    _timer?.cancel();
    _timer=null;
  }
}