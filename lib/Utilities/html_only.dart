// import 'dart:html' as html;
import 'package:web/web.dart' as web;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/constants.dart';
import '../screens/calendar_page.dart';

Text reloadWithNewVersion(double reqSoftwareVersion) {
  if (kIsWeb) {
    // final timestamp = DateTime
    //     .now()
    //     .millisecondsSinceEpoch;
    // String newURL = '${web.window.location.href}?v=$timestamp';
    // String newURL = '${html.window.location.pathname}?v=$timestamp';
    if (kDebugMode) {
      print('NEED NEW VERSION OF THE SOFTWARE $reqSoftwareVersion > $softwareVersion');
    }
    web.window.location.reload();

    // print('trying web.window.location.assign to force reload');
    // final timestamp = DateTime.now().millisecondsSinceEpoch;
    // final newURL = '${web.window.location.href}?v=$timestamp';
    // web.window.location.assign(newURL);

    // web.window.location.replace(newURL);
    // html.window.location.reload();

    // Future.delayed(Duration(milliseconds: 1000), () {
    //   // if (html.window.location.href != newURL) {
    //   //   html.window.location.href = newURL;
    //   // }
    //   if (web.window.location.href != newURL) {
    //     web.window.location.href = newURL;
    //   }
    // });
  }
  return Text('YOU MUST FORCE A RELOAD you need V$reqSoftwareVersion', style: nameStyle,);

}
Text reloadHtml(double reqSoftwareVersion) {
  // if (web.window.navigator.serviceWorker != null) {
  //   web.window.navigator.serviceWorker!.getRegistrations().then((registrations) {
  //     for (var reg in registrations) {
  //       print('unregister worker ${reg.toString()}');
  //       reg.unregister();
  //     }
  //     print('Service worker cleared');
  //     reloadWithNewVersion(reqSoftwareVersion);
  //   });
  // } else
  {
    return reloadWithNewVersion(reqSoftwareVersion);
  }
}
Future<void> downloadCsvFile(Event event) async {
  // this function exists so that the parent function does not have to be async
  Reference ref = event.fileRef!;
  final url = await ref.getDownloadURL();

  // html.AnchorElement(
  //   href: url,
  // )
  //   ..setAttribute('download', event.toString())
  //   ..click();

  web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..setAttribute('download', event.toString())
    ..click();

}