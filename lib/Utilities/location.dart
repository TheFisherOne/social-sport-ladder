import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';


class LocationService {
  final Location _locService = Location();
  bool _serviceEnabled=false;
  LocationData? _lastLocation;
  DateTime? _lastUpdateTime;
  dynamic _pageToRefresh;

  askForSetState(page){
    _pageToRefresh = page;
  }

  Future<LocationData?> updateLocation() async {
    _lastUpdateTime = DateTime.now(); // save the time of the request not the result to prevent infinite loops
    _lastLocation = await _locService.getLocation();
    if (_lastLocation != null ){
      // print('updateLocation: ${_lastLocation!.latitude}, ${_lastLocation!.longitude}');
    } else {
      if (kDebugMode) {
        print('updateLocation: got null');
      }
    }

    return _lastLocation;
  }

  (LocationData?, int) getLast(){
    if (_lastUpdateTime == null ) return (null, 9999);
    int seconds = DateTime.now().difference(_lastUpdateTime!).inSeconds;
    return (_lastLocation, seconds);
  }
  Timer? _timer;
  void init() async {
    _serviceEnabled = await _locService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locService.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }
    _timer = Timer.periodic(Duration(seconds: 20), (_){
      updateLocation();
      if (_pageToRefresh != null) {
        _pageToRefresh!.refresh();
        _pageToRefresh = null;
      }
    });
    updateLocation();

 }
  void dispose() {
    _timer?.cancel();
  }
}