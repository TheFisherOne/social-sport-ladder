#!/bin/bash

current_version=$(grep -oP 'const int softwareVersion = \K\d+' lib/constants/constants.dart)

next_version=$((current_version + 1))

echo Changing Version from "$current_version" to "$next_version"

sed -i "s/const int softwareVersion = $current_version;/const int softwareVersion = $next_version;/;s/bool enableImages = false;/bool enableImages = true;/" lib/constants/constants.dart
#sed -i -E "s|(flutter_bootstrap\\.js)\\?v=[0-9]+|\\1?v=${next_version}|g" web/index.html
sed -i -E "s|(/sw\\.js)\\?v=[0-9]+|\\1?v=${next_version}|g" web/index.html

# this updates pubspec.yaml which in turn will update build/web/version.json which is used to clear the cache
sed -i -E "s/(version: 1\.0\.0\+)[0-9]+/\1$next_version/" pubspec.yaml

# Prepare for deployment by using the correct service worker
echo "Preparing for deployment: copying sw.release.js to sw.js"
cp web/sw.release.js web/sw.js

if [ "$1" = "debug" ]; then
  echo deploying debug version to make stack traces readable V$next_version
  flutter build web --profile --dart-define=Dart2jsOptimization=O0 --pwa-strategy=none
else
 echo deploying in normal mode V$next_version

 flutter build web --pwa-strategy=none
fi

echo adding custom-pages
cp -r custom-pages/info build/web/

echo Deploying web to firebase
firebase deploy

echo "Restoring sw.js for debugging: copying sw.debug.js to sw.js"
cp web/sw.debug.js web/sw.js
echo DONE: Changing Version from "$current_version" to "$next_version"