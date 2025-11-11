// import 'dart:html' as html;
import 'package:web/web.dart' as web;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/constants.dart';
import '../screens/calendar_page.dart';

Widget reloadWithNewVersion(BuildContext context, double reqSoftwareVersion) {
  if (kIsWeb) {
    // final timestamp = DateTime
    //     .now()
    //     .millisecondsSinceEpoch;
    // String newURL = '${web.window.location.href}?v=$timestamp';
    // String newURL = '${html.window.location.pathname}?v=$timestamp';
    if (kDebugMode) {
      print('NEED NEW VERSION OF THE SOFTWARE $reqSoftwareVersion > $softwareVersion');
    }
    // final timestamp = DateTime.now().millisecondsSinceEpoch;
    // final currentUrl = web.window.location.href.split('?')[0]; // Remove existing query params
    // final newURL = '$currentUrl?v=$timestamp';
    //
    // // Use assign() to navigate to the new URL, forcing a reload.
    // web.window.location.assign(newURL);

      return Container(
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(100),
          border: Border.all(color: Colors.red.shade700, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.system_update, color: Colors.red.shade700, size: 40),
            const SizedBox(height: 12),
            Text(
              'Update Required',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: Theme.of(context).textTheme.titleLarge?.fontSize,
                color: Colors.red.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A mandatory update (v$reqSoftwareVersion) is available. Please reload the app to continue.'
              '\nyou may have to reload several times to see the update',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reload Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                // The reload is now safely triggered by direct user action.
                if (kIsWeb) {
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  // Get the base URL without any old query parameters.
                  final currentUrl = web.window.location.href.split('?')[0];
                  final newURL = '$currentUrl?v=$timestamp';
                  // Use assign() to force a full page reload from the server.
                  web.window.location.assign(newURL);
                }
              },
            ),
          ],
        ),
      );

  }
  return Text('YOU MUST FORCE A RELOAD you need V$reqSoftwareVersion', style: nameStyle,);

}
Widget reloadHtml(BuildContext context, double reqSoftwareVersion) {
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
    return reloadWithNewVersion(context, reqSoftwareVersion);
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