import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:timezone/timezone.dart' as tz;

int daysBetween(DateTime from, DateTime to) {
  from = DateTime(from.year, from.month, from.day);
  to = DateTime(to.year, to.month, to.day);
  return (to.difference(from).inHours / 24).round();
}

tz.TZDateTime getDateTimeNow(){
  String locationString='America/Edmonton';
  try {
    locationString = activeLadderDoc!.get('TimeZone');
    // print('read timezone $locationString');
  } catch(_){}
  final tz.Location location = tz.getLocation(locationString);
  return tz.TZDateTime.now(location);
}
