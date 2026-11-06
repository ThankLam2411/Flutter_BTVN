import '../models/dca_models.dart';

enum PlanField { acctNo, symbol, investAmount, investDay, orderTime }

/// Trạng thái form (có thể chưa hợp lệ).
class PlanDraft {
  const PlanDraft({
    this.acctNo,
    this.symbol,
    this.investAmount,
    this.investCycle = InvestCycle.daily,
    this.investDay = '',
    this.orderTime = PlanValidator.defaultOrderTime,
    this.oddLotAllow = true,
  });

  final String? acctNo;
  final String? symbol;
  final int? investAmount;
  final InvestCycle investCycle;
  final String investDay;
  final String orderTime;
  final bool oddLotAllow;

  /// Chỉ gọi sau khi [PlanValidator.validate] trả về rỗng.
  PlanRequest toRequest({
    required LaunchContext context,
    required DateTime createdAt,
  }) =>
      PlanRequest(
        acctNo: acctNo!,
        custodyCd: context.custodyCd,
        custId: context.custId,
        symbol: symbol!,
        investAmount: investAmount!,
        investCycle: investCycle,
        investDay: investCycle == InvestCycle.daily ? '' : investDay,
        orderTime: orderTime,
        oddLotAllow: oddLotAllow,
        createdAt: createdAt,
      );
}

/// Quy tắc nghiệp vụ – bám theo validateInputPlan / form của AutoTrading (iBoard).
abstract final class PlanValidator {
  static const defaultOrderTime = '09:15';
  static const tradingWindowMessage =
      'Giờ phải nằm trong khoảng 9h15 đến 11h30 hoặc 13h đến 14h30!';

  static const _start = 9 * 60 + 15;
  static const _breakStart = 11 * 60 + 30;
  static const _breakEnd = 13 * 60;
  static const _end = 14 * 60 + 30;

  static Map<PlanField, String> validate(
    PlanDraft draft, {
    required LaunchContext context,
  }) {
    final errors = <PlanField, String>{};

    final acctNo = draft.acctNo;
    if (acctNo == null || !context.subAccounts.any((a) => a.id == acctNo)) {
      errors[PlanField.acctNo] = 'Vui lòng chọn số tiểu khoản!';
    }

    final symbol = draft.symbol;
    if (symbol == null || symbol.isEmpty) {
      errors[PlanField.symbol] = 'Vui lòng điền mã chứng khoán!';
    } else if (!context.symbols.contains(symbol)) {
      errors[PlanField.symbol] = 'Mã $symbol không có trong danh sách giao dịch!';
    }

    final amount = draft.investAmount;
    if (amount == null || amount <= 0) {
      errors[PlanField.investAmount] = 'Bạn chưa nhập số tiền đầu tư!';
    }

    switch (draft.investCycle) {
      case InvestCycle.daily:
        break;
      case InvestCycle.weekly:
        if (!weekDayLabels.containsKey(draft.investDay)) {
          errors[PlanField.investDay] = 'Vui lòng chọn thứ trong tuần!';
        }
      case InvestCycle.monthly:
        final day = int.tryParse(draft.investDay);
        if (day == null || day < 1 || day > 31) {
          errors[PlanField.investDay] = 'Vui lòng chọn ngày trong tháng!';
        }
    }

    if (!isValidOrderTime(draft.orderTime)) {
      errors[PlanField.orderTime] = tradingWindowMessage;
    }
    return errors;
  }

  /// 09:15–11:30 hoặc 13:00–14:30 (bao gồm 2 đầu mút, giống moment.isBefore/isAfter bên React).
  static bool isValidOrderTime(String hhmm) {
    final minutes = _toMinutes(hhmm);
    if (minutes == null) return false;
    if (minutes < _start || minutes > _end) return false;
    if (minutes > _breakStart && minutes < _breakEnd) return false;
    return true;
  }

  static int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }
}
