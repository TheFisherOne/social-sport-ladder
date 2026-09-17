import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:social_sport_ladder/constants/constants.dart';

import '../screens/calendar_page.dart';

void reloadWithNewVersion(double reqSoftwareVersion) {

}

Future<void> _openPlayStore(BuildContext context) async {
  final Uri playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.example.social_sport_ladder',
  );

  final bool opened = await launchUrl(
    playStoreUri,
    mode: LaunchMode.externalApplication,
  );

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open Google Play. Please update the app manually.'),
      ),
    );
  }
}

Widget reloadHtml(BuildContext context, double reqSoftwareVersion) {
  final ThemeData theme = Theme.of(context);

  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        elevation: 10,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.orange.shade100,
                child: Icon(
                  Icons.system_update_alt_rounded,
                  size: 34,
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update required',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This version is no longer supported. Please update the Android app to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_outlined, size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Current version: $softwareVersion',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.new_releases_outlined, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Required version: $reqSoftwareVersion',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openPlayStore(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Google Play'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'If you are on a beta track, the Play Store listing will start working once the app is published there.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> downloadCsvFile(Event event) async {

}
void changeLoadingMessage(String message){

}
void flutterAppReady() {
    if (kDebugMode) {
      print('Attempt to call flutterAppReady');
    }
}