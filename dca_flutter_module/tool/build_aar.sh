#!/bin/sh
# Build Flutter Module thành AAR (Maven repo local) cho app Android host.
#   => build/host/outputs/repo/vn/com/bsc/dca_flutter_module/flutter_{debug,profile,release}/1.0/
# App host khai báo repo này trong settings.gradle.kts (xem android_host_app).
set -e
cd "$(dirname "$0")/.."
flutter pub get
flutter build aar "$@"
