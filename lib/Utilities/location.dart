import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';

import '../screens/ladder_config_page.dart';


class LocationService {
  final Location _locService = Location();
  bool _serviceEnabled=false;
  LocationData? _lastLocation;
  DateTime? _lastUpdateTime;
  dynamic _pageToRefresh;
  double _lastDistanceAway=9999.0;
  bool _lastLocationOk = false;
  double _lastDistanceRefresh = 8888.0;
  bool isLastLocationOk(){
    return _lastLocationOk;
  }

  double getLastDistanceAway(){
    return _lastDistanceAway;
  }
  askForSetState(page){
    _pageToRefresh = page;
  }

 Future<bool> updateLocation() async {
    _lastUpdateTime = DateTime.now(); // save the time of the request not the result to prevent infinite loops
    _lastLocation = await _locService.getLocation();
    if (_lastLocation != null ){
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

  (LocationData?, int) getLast(){
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
  bool isLocationOk( LocationData where) {
    if ((where.latitude == null) || (where.longitude == null)) return false;
    double allowedDistance = activeLadderDoc!.get('MetersFromLatLong');
    if (allowedDistance <= 0.0) return true; // this is disabled

    double distance = measureDistance(activeLadderDoc!.get('Latitude'), activeLadderDoc!.get('Longitude'), where.latitude!, where.longitude!);

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
    _pageToRefresh = null;
    _timer?.cancel();
    _timer=null;
  }
  void init() async {
    _serviceEnabled = await _locService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locService.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }
    startTimer();

 }
  void dispose() {
    _timer?.cancel();
    _timer=null;
  }
}