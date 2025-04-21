import 'dart:html' as html;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/constants.dart';
import '../screens/calendar_page.dart';

reloadWithNewVersion(double reqSoftwareVersion) {
  if (kIsWeb) {
    // html.window.location.reload();
    final timestamp = DateTime
        .now()
        .millisecondsSinceEpoch;
    String newURL = '${html.window.location.pathname}?v=$timestamp';
    if (kDebugMode) {
      print('NEED NEW VERSION OF THE SOFTWARE $reqSoftwareVersion > $softwareVersion $newURL');
    }
    html.window.location.reload();

    Future.delayed(Duration(milliseconds: 1000), () {
      if (html.window.location.href != newURL) {
        html.window.location.href = newURL;
      }
    });
    return Text('YOU MUST FORCE A RELOAD you need V$reqSoftwareVersion', style: nameStyle,);
  }
}
void reloadHtml(double reqSoftwareVersion) {
  if (html.window.navigator.serviceWorker != null) {
    html.window.navigator.serviceWorker!.getRegistrations().then((registrations) {
      for (var reg in registrations) {
        print('unregister worker ${reg.toString()}');
        reg.unregister();
      }
      print('Service worker cleared');
      reloadWithNewVersion(reqSoftwareVersion);
    });
  } else {
    reloadWithNewVersion(reqSoftwareVersion);
  }
}
downloadCsvFile(Event event) async {
  // this function exists so that the parent function does not have to be async
  Reference ref = event.fileRef!;
  final url = await ref.getDownloadURL();

  html.AnchorElement(
    href: url,
  )
    ..setAttribute('download', event.toString())
    ..click();
}