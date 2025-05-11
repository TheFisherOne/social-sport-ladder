#!/bin/bash

current_version=$(grep -oP 'const int softwareVersion = \K\d+' lib/constants/constants.dart)

next_version=$((current_version + 1))

echo Changing Version from "$current_version" to "$next_version"

sed -i "s/const int softwareVersion = $current_version;/const int softwareVersion = $next_version;/;s/bool enableImages = false;/bool enableImages = true;/" lib/constants/constants.dart

flutter build web
firebase deploy
