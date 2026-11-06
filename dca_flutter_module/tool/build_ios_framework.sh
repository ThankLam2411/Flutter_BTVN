#!/bin/sh
# Build Flutter Module thành XCFramework và đặt vào ios_host_app/Flutter/{Debug,Profile,Release}
#   App.xcframework                  - code Dart (AOT ở Release) + assets của Module
#   Flutter.xcframework              - Flutter engine
#   FlutterPluginRegistrant.xcframework - đăng ký plugin (Module này không dùng plugin)
set -e
cd "$(dirname "$0")/.."
flutter pub get
flutter build ios-framework --output=../ios_host_app/Flutter "$@"
echo "XCFrameworks => ../ios_host_app/Flutter"
