#!/bin/sh
# Sinh code Pigeon:
#   - lib/src/pigeons/dca_messages.g.dart
#   - ../ios_host_app/DcaHost/Bridge/DcaMessages.g.swift
#   - ../android_host_app/app/src/main/kotlin/vn/com/bsc/dcahost/bridge/DcaMessages.g.kt
set -e
cd "$(dirname "$0")/.."
mkdir -p lib/src/pigeons ../ios_host_app/DcaHost/Bridge \
  ../android_host_app/app/src/main/kotlin/vn/com/bsc/dcahost/bridge
flutter pub get
dart run pigeon --input pigeons/dca_messages.dart
echo "Pigeon: done"
