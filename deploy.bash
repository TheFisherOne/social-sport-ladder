#!/bin/bash
if [ "$1" = "webonly" ] && [ ! -d "build/web" ]; then
  echo "Error: build/web/ directory doesn't exist. Run without webonly first."
  exit 1
fi

if [ "$1" != "webonly" ]; then
  current_version=$(grep -oP 'const int softwareVersion = \K\d+' lib/constants/constants.dart)

  next_version=$((current_version + 1))

  echo Changing Version from "$current_version" to "$next_version"

  sed -i "s/const int softwareVersion = $current_version;/const int softwareVersion = $next_version;/;s/bool enableImages = false;/bool enableImages = true;/" lib/constants/constants.dart

  # keep Android/iOS build metadata aligned with the app software version
  sed -i -E "s/^(version: [0-9]+\.[0-9]+\.[0-9]+\+)[0-9]+$/\1$next_version/" pubspec.yaml

  flutter pub get

fi

if [ "$1" != "webonly" ]; then
  if [ "$1" = "debug" ]; then
    echo deploying debug version to make stack traces readable V$next_version
    flutter build web --profile --dart-define=Dart2jsOptimization=O0
  else
   echo deploying in normal mode V$next_version

   flutter build web

   echo building Android app bundle V$next_version
     if [ ! -f android/key.properties ]; then
       echo "Error: android/key.properties not found. Configure Android release signing before building the app bundle."
       echo "Tip: create android/key.properties with storeFile, storePassword, keyAlias, and keyPassword."
       exit 1
     fi
   flutter build appbundle --release
  fi
fi

echo adding custom-pages
cp -r custom-pages/info build/web/


if [ "$1" = "debug" ]; then
  echo DEPLOYING DEBUG VERSION ONLY V$next_version
  firebase hosting:channel:deploy "debug-v$next_version" --expires 1d
else
  echo Deploying web to firebase
  firebase deploy
fi

if [ "$1" != "webonly" ]; then
  echo DONE: Changing Version from "$current_version" to "$next_version"
  echo Android bundle in build/app/outputs/bundle/release/app-release.aab
else
  echo DONE: just updating the web server, not compiling the code
fi