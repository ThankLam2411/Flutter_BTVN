import 'dart:async';

import 'package:dca_flutter_module/src/bridge/dca_host.dart';
import 'package:dca_flutter_module/src/logic/dca_form_controller.dart';
import 'package:dca_flutter_module/src/logic/plan_validator.dart';
import 'package:dca_flutter_module/src/models/dca_models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHost implements DcaHost {
  PlanRequest? lastSubmitted;
  DcaHostException? submitError;

  @override
  Stream<String> get routeRequests => const Stream.empty();

  @override
  Future<void> notifyReady() async {}

  @override
  Future<LaunchContext> getLaunchContext() async => const LaunchContext(
        custodyCd: '021C668899',
        custId: '0001234567',
        subAccounts: [
          SubAccount(id: 'A1', type: 'Thường'),
          SubAccount(id: 'A2', type: 'Ký quỹ'),
        ],
        symbols: ['FPT', 'ROS'],
        defaultAcctNo: 'A2',
      );

  @override
  Future<SubmitResult> submitPlan(PlanRequest request) async {
    lastSubmitted = request;
    final error = submitError;
    if (error != null) throw error;
    return const SubmitResult(quoteId: 'Q1', message: 'OK');
  }

  @override
  Future<void> finishSubmitted(SubmittedPlan plan) async {}

  @override
  Future<void> finishCancelled() async {}

  @override
  Stream<MarketSession> marketSession() => const Stream.empty();
}

void main() {
  late FakeHost host;
  late DcaFormController c;

  setUp(() {
    host = FakeHost();
    c = DcaFormController(host, clock: () => DateTime(2026, 11, 6, 10));
  });

  test('start: lấy Arguments, chọn tiểu khoản mặc định & mã preset', () async {
    await c.start(presetSymbol: 'fpt');
    expect(c.loadState, LoadState.ready);
    expect(c.draft.acctNo, 'A2');
    expect(c.draft.symbol, 'FPT');
  });

  test('preset không có trong danh sách => bỏ qua', () async {
    await c.start(presetSymbol: 'XYZ');
    expect(c.draft.symbol, isNull);
  });

  test('submit thiếu dữ liệu => có lỗi, không gọi Host', () async {
    await c.start();
    final result = await c.submit();
    expect(result, isNull);
    expect(c.errors.keys, containsAll([PlanField.symbol, PlanField.investAmount]));
    expect(host.lastSubmitted, isNull);
  });

  test('đổi chu kỳ => reset Lặp vào ngày', () async {
    await c.start();
    c.setInvestCycle(InvestCycle.weekly);
    c.setInvestDay('monday');
    c.setInvestCycle(InvestCycle.monthly);
    expect(c.draft.investDay, '');
  });

  test('submit hợp lệ => gửi đúng dữ liệu sang Host', () async {
    await c.start(presetSymbol: 'FPT');
    c
      ..setInvestAmount(2000000)
      ..setInvestCycle(InvestCycle.weekly)
      ..setInvestDay('friday')
      ..setOrderTime('13:30')
      ..setOddLotAllow(false);

    final submitted = await c.submit();
    expect(submitted?.result.quoteId, 'Q1');
    final r = host.lastSubmitted!;
    expect(r.acctNo, 'A2');
    expect(r.symbol, 'FPT');
    expect(r.investAmount, 2000000);
    expect(r.investCycle, InvestCycle.weekly);
    expect(r.investDay, 'friday');
    expect(r.orderTime, '13:30');
    expect(r.oddLotAllow, isFalse);
    expect(r.custodyCd, '021C668899');
  });

  test('Host từ chối (PigeonError) => hiển thị submitError', () async {
    host.submitError = const DcaHostException('SYMBOL_RESTRICTED', 'Mã ROS bị hạn chế');
    await c.start(presetSymbol: 'ROS');
    c.setInvestAmount(1000000);
    final submitted = await c.submit();
    expect(submitted, isNull);
    expect(c.submitError, 'Mã ROS bị hạn chế');
    expect(c.submitting, isFalse);
  });
}
