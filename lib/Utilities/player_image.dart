import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../constants/constants.dart';

Map<String,String?> playerImageCache = {};

Future<bool> getPlayerImage(String playerEmail, {bool overrideCache = false}) async {
  if (!enableImages) return false;
  if (!overrideCache && ( playerImageCache.containsKey(playerEmail))){
    // print('Ladder image for $ladderId found in cache ${urlCache[ladderId]}');
    return false;
  }
  // due to async we will come in here multiple times while we are waiting.
  // by putting an entry in the cache even though it is null, we should only ask once
  playerImageCache[playerEmail] = null;
  String filename = 'PlayerImage/$playerEmail.jpg';

  final storage = FirebaseStorage.instance;
  final ref = storage.ref(filename);
  // print('getPlayerImage: for $filename');
  try {
    final url = await ref.getDownloadURL();
    // print('URL: $url');
    playerImageCache[playerEmail] = url;
    // print('Image $filename downloaded successfully! $url');
  } catch (e) {
    if (e is FirebaseException) {
      // print('FirebaseException: ${e.code} - ${e.message}');
    } else if (e is SocketException) {
      if (kDebugMode) {
        print('SocketException: ${e.message}');
      }
    } else {
      if (kDebugMode) {
        print('downloadLadderImage: getData exception: ${e.runtimeType} || ${e.toString()}');
      }
    }

    return false;
  }
  // print('SUCCESS');
  return true;
}
Future<void> uploadPlayerPicture(XFile file, String playerId) async {
  String filename = 'PlayerImage/$playerId.jpg';
  Uint8List fileData;
  img.Image? image;
  try {
    fileData = await file.readAsBytes();
  } catch (e) {
    if (kDebugMode) {
      print('error on readAsBytes $e');
    }
    return;
  }
  // print('now doing decodeImage');
  try {
    image = img.decodeImage(fileData);
  } catch (e) {
    if (kDebugMode) {
      print('error on decode $e');
    }
    return;
  }
  if (image == null) return;

  // print('now doing copyResize');
  img.Image resized = img.copyResize(image, height: 100);
  try {
    // print('now doing putData to: $filename');
    await FirebaseStorage.instance.ref(filename).putData(img.encodePng(resized));
  } catch (e) {
    if (kDebugMode) {
      print('Error on write to storage $e');
    }
  }
  // print('Done saving file');
  // urlCache.remove(activeLadderId);
  if (await getPlayerImage(playerId,overrideCache: true)) {
    if (kDebugMode) {
      print('loaded new image for $playerId');
    }
  }
}
