#!/bin/bash
set -e
cd ..
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"
flutter config --no-analytics
cd app
flutter pub get
flutter build web --release
rm -rf ../web/public
mkdir -p ../web/public
cp -r build/web/. ../web/public/
