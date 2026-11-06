/// Model nội bộ của Module (độc lập với code Pigeon sinh ra).
library;

/// Chu kỳ lặp – nhãn giống INVEST_CYCLE của iBoard.
enum InvestCycle {
  daily('Hàng ngày'),
  weekly('Hàng tuần'),
  monthly('Hàng tháng');

  const InvestCycle(this.label);
  final String label;
}

/// Các thứ trong tuần được phép chọn khi chu kỳ = weekly (giá trị gửi đi giống iBoard).
const Map<String, String> weekDayLabels = {
  'monday': 'Thứ Hai',
  'tuesday': 'Thứ Ba',
  'wednesday': 'Thứ Tư',
  'thursday': 'Thứ Năm',
  'friday': 'Thứ Sáu',
};

typedef InvestDayOption = ({String value, String label});

/// Danh sách lựa chọn "Lặp vào ngày" theo chu kỳ.
List<InvestDayOption> investDayOptions(InvestCycle cycle) => switch (cycle) {
      InvestCycle.daily => const [],
      InvestCycle.weekly => [
          for (final e in weekDayLabels.entries) (value: e.key, label: e.value),
        ],
      InvestCycle.monthly => [
          for (var d = 1; d <= 31; d++) (value: '$d', label: 'Ngày $d'),
        ],
    };

String investDayLabel(InvestCycle cycle, String investDay) => switch (cycle) {
      InvestCycle.daily => 'Mỗi ngày giao dịch',
      InvestCycle.weekly => weekDayLabels[investDay] ?? investDay,
      InvestCycle.monthly => 'Ngày $investDay hàng tháng',
    };

class SubAccount {
  const SubAccount({required this.id, required this.type});

  final String id;
  final String type;

  String get display => '$id - $type';
}

/// Arguments Host App truyền khi mở Module.
class LaunchContext {
  const LaunchContext({
    required this.custodyCd,
    required this.custId,
    required this.subAccounts,
    required this.symbols,
    this.defaultAcctNo,
  });

  final String custodyCd;
  final String custId;
  final List<SubAccount> subAccounts;
  final List<String> symbols;
  final String? defaultAcctNo;
}

/// Kế hoạch đầu tư định kỳ đã hợp lệ, sẵn sàng gửi cho Host App.
class PlanRequest {
  const PlanRequest({
    required this.acctNo,
    required this.custodyCd,
    required this.custId,
    required this.symbol,
    required this.investAmount,
    required this.investCycle,
    required this.investDay,
    required this.orderTime,
    required this.oddLotAllow,
    required this.createdAt,
  });

  final String acctNo;
  final String custodyCd;
  final String custId;
  final String symbol;
  final int investAmount;
  final InvestCycle investCycle;
  final String investDay;
  final String orderTime;
  final bool oddLotAllow;
  final DateTime createdAt;
}

class SubmitResult {
  const SubmitResult({required this.quoteId, required this.message});

  final String quoteId;
  final String message;
}

/// Kế hoạch đã được Host App chấp nhận.
class SubmittedPlan {
  const SubmittedPlan(this.request, this.result);

  final PlanRequest request;
  final SubmitResult result;
}

/// Trạng thái phiên giao dịch – stream từ Host App qua EventChannel.
class MarketSession {
  const MarketSession({
    required this.code,
    required this.label,
    required this.serverTime,
  });

  /// Decode Map do StandardMessageCodec gửi sang:
  /// {code: String, label: String, serverTimeMillis: int (UTC)}
  factory MarketSession.fromMap(Map<Object?, Object?> map) => MarketSession(
        code: map['code'] as String? ?? 'UNKNOWN',
        label: map['label'] as String? ?? '',
        serverTime: DateTime.fromMillisecondsSinceEpoch(
          map['serverTimeMillis'] as int? ?? 0,
          isUtc: true,
        ).toLocal(),
      );

  final String code;
  final String label;
  final DateTime serverTime;
}

/// Lỗi từ Host App (map từ PlatformException / PigeonError).
class DcaHostException implements Exception {
  const DcaHostException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DcaHostException($code): $message';
}
