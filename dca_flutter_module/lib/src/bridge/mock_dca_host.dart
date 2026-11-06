import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/dca_models.dart';
import 'dca_host.dart';

/// Host giả lập để chạy Module độc lập (`flutter run`) mà không cần app iOS.
/// Hành vi giống DcaHostApiImpl bên Swift: delay, từ chối mã bị hạn chế, stream phiên.
class MockDcaHost implements DcaHost {
  MockDcaHost({this.initialRoute = '/plan/new?symbol=FPT'});

  final String initialRoute;
  static const _restrictedSymbols = {'ROS'};

  final StreamController<String> _routes = StreamController<String>.broadcast();

  @override
  Stream<String> get routeRequests => _routes.stream;

  @override
  Future<void> notifyReady() async => _openLater(initialRoute);

  @override
  Future<LaunchContext> getLaunchContext() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const LaunchContext(
      custodyCd: '021C668899',
      custId: '0001234567',
      subAccounts: [
        SubAccount(id: '0216688991', type: 'Thường'),
        SubAccount(id: '0216688996', type: 'Ký quỹ'),
      ],
      symbols: ['ACB', 'BID', 'FPT', 'HPG', 'MBB', 'MWG', 'ROS', 'SSI', 'VCB', 'VNM'],
      defaultAcctNo: '0216688991',
    );
  }

  @override
  Future<SubmitResult> submitPlan(PlanRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_restrictedSymbols.contains(request.symbol)) {
      throw DcaHostException(
        'SYMBOL_RESTRICTED',
        'Mã ${request.symbol} đang bị hạn chế giao dịch, không thể lập kế hoạch.',
      );
    }
    return SubmitResult(
      quoteId: 'MOCK-${DateTime.now().millisecondsSinceEpoch}',
      message: 'Mock host đã nhận kế hoạch.',
    );
  }

  @override
  Future<void> finishSubmitted(SubmittedPlan plan) async {
    debugPrint('[MockDcaHost] finish(submitted) ${plan.request.symbol} '
        '${plan.request.investAmount} quoteId=${plan.result.quoteId}');
    _openLater('/plan/new');
  }

  @override
  Future<void> finishCancelled() async {
    debugPrint('[MockDcaHost] finish(cancelled)');
    _openLater('/plan/new');
  }

  @override
  Stream<MarketSession> marketSession() async* {
    yield _sessionAt(DateTime.now());
    yield* Stream.periodic(
      const Duration(seconds: 5),
      (_) => _sessionAt(DateTime.now()),
    );
  }

  /// Giả lập Host mở lại Module sau khi đóng.
  void _openLater(String route) =>
      Timer(const Duration(milliseconds: 600), () => _routes.add(route));

  static MarketSession _sessionAt(DateTime now) {
    final m = now.hour * 60 + now.minute;
    final (code, label) = switch (m) {
      _ when now.weekday >= DateTime.saturday => ('CLOSED', 'Nghỉ cuối tuần'),
      < 540 => ('PRE_OPEN', 'Chưa mở cửa'),
      < 555 => ('ATO', 'Phiên ATO'),
      < 690 => ('CONTINUOUS', 'Khớp lệnh liên tục (sáng)'),
      < 780 => ('BREAK', 'Nghỉ trưa'),
      < 870 => ('CONTINUOUS', 'Khớp lệnh liên tục (chiều)'),
      < 885 => ('ATC', 'Phiên ATC'),
      _ => ('CLOSED', 'Đã đóng cửa'),
    };
    return MarketSession(code: '$code (mock)', label: label, serverTime: now);
  }
}
