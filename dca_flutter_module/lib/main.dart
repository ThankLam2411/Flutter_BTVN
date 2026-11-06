import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/bridge/mock_dca_host.dart';
import 'src/bridge/pigeon_dca_host.dart';

/// Entrypoint mặc định – chạy Module độc lập (`flutter run`) với Host giả lập
/// để phát triển UI/nghiệp vụ mà không cần app iOS.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DcaModuleApp(host: MockDcaHost()));
}

/// Entrypoint khi nhúng vào app iOS:
///   engine.run(withEntrypoint: "dcaPlanMain")
/// @pragma để entrypoint không bị tree-shake ở bản release (AOT).
@pragma('vm:entry-point')
void dcaPlanMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DcaModuleApp(host: PigeonDcaHost()));
}
