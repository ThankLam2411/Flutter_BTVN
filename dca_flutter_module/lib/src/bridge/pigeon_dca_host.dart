import 'dart:async';

import 'package:flutter/services.dart';

import '../models/dca_models.dart';
import '../pigeons/dca_messages.g.dart' as pg;
import 'dca_host.dart';

/// Cài đặt [DcaHost] thật:
///  - Pigeon HostApi   (Flutter -> iOS): flutterReady, getLaunchContext, submitPlan, finish
///  - Pigeon FlutterApi (iOS -> Flutter): navigateTo
///  - EventChannel     (iOS -> Flutter, stream): trạng thái phiên giao dịch
///
/// Lớp này là nơi DUY NHẤT biết tới kiểu dữ liệu Pigeon; phần còn lại của Module
/// chỉ dùng model nội bộ => đổi cơ chế giao tiếp không ảnh hưởng UI/logic.
class PigeonDcaHost implements DcaHost {
  PigeonDcaHost({
    pg.DcaHostApi? hostApi,
    EventChannel? marketSessionChannel,
  })  : _hostApi = hostApi ?? pg.DcaHostApi(),
        _marketSessionChannel = marketSessionChannel ??
            const EventChannel(marketSessionChannelName) {
    // Đăng ký handler FlutterApi NGAY khi khởi tạo, trước khi gọi notifyReady().
    pg.DcaFlutterApi.setUp(_FlutterApiHandler(_routes));
  }

  /// Phải trùng tên với FlutterEventChannel bên iOS (MarketSessionStreamHandler.channelName).
  static const marketSessionChannelName = 'vn.com.bsc.dca/market_session';

  final pg.DcaHostApi _hostApi;
  final EventChannel _marketSessionChannel;
  final StreamController<String> _routes = StreamController<String>.broadcast();

  @override
  Stream<String> get routeRequests => _routes.stream;

  @override
  Future<void> notifyReady() => _guard(_hostApi.flutterReady);

  @override
  Future<LaunchContext> getLaunchContext() => _guard(() async {
        final m = await _hostApi.getLaunchContext();
        final subAccounts = [
          for (final a in m.subAccounts) SubAccount(id: a.id, type: a.type),
        ];
        final defaultAcct = m.defaultAcctNo;
        return LaunchContext(
          custodyCd: m.custodyCd,
          custId: m.custId,
          subAccounts: List.unmodifiable(subAccounts),
          symbols: List.unmodifiable([...m.symbols]..sort()),
          defaultAcctNo:
              subAccounts.any((a) => a.id == defaultAcct) ? defaultAcct : null,
        );
      });

  @override
  Future<SubmitResult> submitPlan(PlanRequest request) => _guard(() async {
        final r = await _hostApi.submitPlan(_toMessage(request));
        return SubmitResult(quoteId: r.quoteId, message: r.message);
      });

  @override
  Future<void> finishSubmitted(SubmittedPlan plan) => _guard(
        () => _hostApi.finish(
          pg.DcaFlowResult(
            status: pg.DcaFlowStatus.submitted,
            plan: _toMessage(plan.request),
            quoteId: plan.result.quoteId,
          ),
        ),
      );

  @override
  Future<void> finishCancelled() => _guard(
        () => _hostApi.finish(
          pg.DcaFlowResult(status: pg.DcaFlowStatus.cancelled),
        ),
      );

  @override
  Stream<MarketSession> marketSession() => _marketSessionChannel
          .receiveBroadcastStream()
          .map((event) => MarketSession.fromMap(
                Map<Object?, Object?>.from(event as Map),
              ))
          .handleError((Object e) {
        throw e is PlatformException
            ? DcaHostException(e.code, e.message ?? 'Lỗi stream phiên giao dịch')
            : e;
      });

  // -------------------------------------------------------------------------

  /// PlatformException (do PigeonError/FlutterError bên iOS) -> DcaHostException.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw DcaHostException(e.code, e.message ?? 'Lỗi không xác định từ app.');
    }
  }

  static pg.DcaPlanRequest _toMessage(PlanRequest p) => pg.DcaPlanRequest(
        acctNo: p.acctNo,
        custodyCd: p.custodyCd,
        custId: p.custId,
        symbol: p.symbol,
        investAmount: p.investAmount,
        investCycle: switch (p.investCycle) {
          InvestCycle.daily => pg.DcaInvestCycle.daily,
          InvestCycle.weekly => pg.DcaInvestCycle.weekly,
          InvestCycle.monthly => pg.DcaInvestCycle.monthly,
        },
        investDay: p.investDay,
        orderTime: p.orderTime,
        oddLotAllow: p.oddLotAllow,
        // DateTime không đi qua channel được -> timestamp UTC.
        createdAtMillis: p.createdAt.toUtc().millisecondsSinceEpoch,
      );
}

class _FlutterApiHandler implements pg.DcaFlutterApi {
  _FlutterApiHandler(this._routes);

  final StreamController<String> _routes;

  @override
  void navigateTo(String route) => _routes.add(route);
}
