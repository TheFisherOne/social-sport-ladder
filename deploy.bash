#!/bin/bash

current_version=$(grep -oP 'const int softwareVersion = \K\d+' lib/constants/constants.dart)

next_version=$((current_version + 1))

echo Changing Version from "$current_version" to "$next_version"

sed -i "s/const int softwareVersion = $current_version;/const int softwareVersion = $next_version;/;s/bool enableImages = false;/bool enableImages = true;/" lib/constants/constants.dart

sed -i -E "s/(flutter\.js\?version=)[0-9]+/\1$next_version/" web/index.html

if [ "$1" = "debug" ]; then
  echo deploying debug version to make stack traces readable V$next_version
  flutter build web --profile --dart-define=Dart2jsOptimization=O0
else
 echo deploying in normal mode V$next_version

 flutter build web --pwa-strategy=none --release
fi

echo adding custom-pages
cp -r custom-pages/info build/web/

echo Deploying web to firebase
firebase deploy
