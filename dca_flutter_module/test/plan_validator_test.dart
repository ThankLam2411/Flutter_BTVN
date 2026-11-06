import 'package:dca_flutter_module/src/logic/plan_validator.dart';
import 'package:dca_flutter_module/src/models/dca_models.dart';
import 'package:flutter_test/flutter_test.dart';

const ctx = LaunchContext(
  custodyCd: '021C668899',
  custId: '0001234567',
  subAccounts: [SubAccount(id: '0216688991', type: 'Thường')],
  symbols: ['FPT', 'VNM'],
);

const valid = PlanDraft(
  acctNo: '0216688991',
  symbol: 'FPT',
  investAmount: 1000000,
);

void main() {
  group('isValidOrderTime (09:15–11:30, 13:00–14:30)', () {
    for (final t in ['09:15', '10:00', '11:30', '13:00', '14:30']) {
      test('$t hợp lệ', () => expect(PlanValidator.isValidOrderTime(t), isTrue));
    }
    for (final t in ['09:14', '11:31', '12:00', '12:59', '14:31', '8:00', 'abc', '25:00']) {
      test('$t không hợp lệ',
          () => expect(PlanValidator.isValidOrderTime(t), isFalse));
    }
  });

  group('validate', () {
    test('draft đầy đủ (daily) => không lỗi', () {
      expect(PlanValidator.validate(valid, context: ctx), isEmpty);
    });

    test('thiếu mã CK, số tiền, tiểu khoản', () {
      final errors = PlanValidator.validate(const PlanDraft(), context: ctx);
      expect(errors.keys,
          containsAll([PlanField.acctNo, PlanField.symbol, PlanField.investAmount]));
      expect(errors[PlanField.symbol], 'Vui lòng điền mã chứng khoán!');
    });

    test('mã không nằm trong danh sách Host cung cấp', () {
      const d = PlanDraft(acctNo: '0216688991', symbol: 'XYZ', investAmount: 1);
      expect(PlanValidator.validate(d, context: ctx).keys, [PlanField.symbol]);
    });

    test('weekly bắt buộc chọn thứ', () {
      const d = PlanDraft(
          acctNo: '0216688991',
          symbol: 'FPT',
          investAmount: 1,
          investCycle: InvestCycle.weekly);
      expect(PlanValidator.validate(d, context: ctx).keys, [PlanField.investDay]);
      const ok = PlanDraft(
          acctNo: '0216688991',
          symbol: 'FPT',
          investAmount: 1,
          investCycle: InvestCycle.weekly,
          investDay: 'friday');
      expect(PlanValidator.validate(ok, context: ctx), isEmpty);
    });

    test('monthly chỉ nhận ngày 1..31', () {
      for (final (day, isValid) in [('1', true), ('31', true), ('0', false), ('32', false), ('', false)]) {
        final d = PlanDraft(
            acctNo: '0216688991',
            symbol: 'FPT',
            investAmount: 1,
            investCycle: InvestCycle.monthly,
            investDay: day);
        expect(PlanValidator.validate(d, context: ctx).isEmpty, isValid,
            reason: 'investDay=$day');
      }
    });

    test('giờ ngoài khung giao dịch', () {
      const d = PlanDraft(
          acctNo: '0216688991', symbol: 'FPT', investAmount: 1, orderTime: '12:00');
      expect(PlanValidator.validate(d, context: ctx)[PlanField.orderTime],
          PlanValidator.tradingWindowMessage);
    });
  });

  test('toRequest: daily luôn gửi investDay rỗng', () {
    const d = PlanDraft(
        acctNo: '0216688991', symbol: 'FPT', investAmount: 500000, investDay: 'monday');
    final r = d.toRequest(context: ctx, createdAt: DateTime(2026, 11, 6));
    expect(r.investDay, '');
    expect(r.custodyCd, ctx.custodyCd);
  });
}
