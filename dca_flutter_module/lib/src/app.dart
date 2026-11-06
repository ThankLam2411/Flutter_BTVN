import 'dart:async';

import 'package:flutter/material.dart';

import 'bridge/dca_host.dart';
import 'logic/dca_form_controller.dart';
import 'models/dca_models.dart';
import 'pages/dca_form_page.dart';
import 'pages/dca_success_page.dart';
import 'pages/splash_page.dart';

abstract final class DcaRoutes {
  /// Màn chờ khi Engine đã warm-up nhưng Host chưa yêu cầu mở luồng nào.
  static const splash = '/';
  static const newPlan = '/plan/new';
  static const success = '/plan/success';
}

/// Root widget của Module.
///
/// Luồng điều hướng (Native -> Flutter -> Native):
///  1. initState: lắng nghe FlutterApi.navigateTo, rồi gọi HostApi.flutterReady().
///  2. Host gọi navigateTo('/plan/new?symbol=FPT') => reset form + HostApi.getLaunchContext().
///  3. Người dùng lập kế hoạch => HostApi.submitPlan() (@async, có thể lỗi).
///  4. "Hoàn tất" / "Đóng" => HostApi.finish(result) => Host dismiss màn Flutter.
class DcaModuleApp extends StatefulWidget {
  const DcaModuleApp({super.key, required this.host});

  final DcaHost host;

  @override
  State<DcaModuleApp> createState() => _DcaModuleAppState();
}

class _DcaModuleAppState extends State<DcaModuleApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final DcaFormController _controller = DcaFormController(widget.host);
  StreamSubscription<String>? _routeSub;
  String _initialRoute = DcaRoutes.splash;

  @override
  void initState() {
    super.initState();
    _routeSub = widget.host.routeRequests.listen(_handleRouteRequest);
    unawaited(_signalReady());
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _signalReady() async {
    try {
      await widget.host.notifyReady();
    } on DcaHostException catch (e) {
      debugPrint('[DCA] flutterReady lỗi: $e');
    }
  }

  void _handleRouteRequest(String route) {
    final uri = Uri.parse(route);
    switch (uri.path) {
      case DcaRoutes.newPlan:
        unawaited(_controller.start(presetSymbol: uri.queryParameters['symbol']));
        _goTo(DcaRoutes.newPlan);
      default:
        debugPrint('[DCA] Route không hỗ trợ: $route');
    }
  }

  void _goTo(String routeName, {Object? arguments}) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _initialRoute = routeName; // Navigator chưa build xong
      return;
    }
    navigator.pushNamedAndRemoveUntil(routeName, (_) => false,
        arguments: arguments);
  }

  Future<void> _cancel() async {
    try {
      await widget.host.finishCancelled();
    } on DcaHostException catch (e) {
      debugPrint('[DCA] finish(cancelled) lỗi: $e');
    }
    _goTo(DcaRoutes.splash);
  }

  void _showSuccess(SubmittedPlan plan) =>
      _goTo(DcaRoutes.success, arguments: plan);

  Future<void> _finishSubmitted(SubmittedPlan plan) async {
    try {
      await widget.host.finishSubmitted(plan);
    } on DcaHostException catch (e) {
      debugPrint('[DCA] finish(submitted) lỗi: $e');
    }
    _goTo(DcaRoutes.splash);
  }

  Route<void> _onGenerateRoute(RouteSettings settings) {
    final Widget page;
    final args = settings.arguments;
    if (settings.name == DcaRoutes.newPlan) {
      page = DcaFormPage(
        controller: _controller,
        host: widget.host,
        onCancel: _cancel,
        onSubmitted: _showSuccess,
      );
    } else if (settings.name == DcaRoutes.success && args is SubmittedPlan) {
      page = DcaSuccessPage(plan: args, onDone: () => _finishSubmitted(args));
    } else {
      page = const SplashPage();
    }
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSC - Đầu tư định kỳ',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00796B),
      ),
      initialRoute: _initialRoute,
      // Không tách '/plan/new' thành ['/', '/plan', '/plan/new'] như mặc định.
      onGenerateInitialRoutes: (name) =>
          [_onGenerateRoute(RouteSettings(name: name))],
      onGenerateRoute: _onGenerateRoute,
    );
  }
}
