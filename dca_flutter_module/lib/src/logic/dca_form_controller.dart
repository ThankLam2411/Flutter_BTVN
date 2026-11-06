import 'package:flutter/foundation.dart';

import '../bridge/dca_host.dart';
import '../models/dca_models.dart';
import 'plan_validator.dart';

enum LoadState { idle, loading, ready, error }

/// State của luồng "Lập kế hoạch đầu tư định kỳ".
///
/// Giữ trạng thái suốt vòng đời Engine (engine được warm-up & tái sử dụng),
/// mỗi lần Host mở Module sẽ gọi [start] để reset form và lấy Arguments mới.
class DcaFormController extends ChangeNotifier {
  DcaFormController(this._host, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DcaHost _host;
  final DateTime Function() _clock;

  LoadState _loadState = LoadState.idle;
  String? _loadError;
  LaunchContext? _context;
  String? _presetSymbol;
  int _generation = 0;

  PlanDraft _draft = const PlanDraft();
  Map<PlanField, String> _errors = const {};
  bool _validateOnChange = false;
  bool _submitting = false;
  String? _submitError;

  LoadState get loadState => _loadState;
  String? get loadError => _loadError;
  LaunchContext? get context => _context;
  PlanDraft get draft => _draft;
  Map<PlanField, String> get errors => _errors;
  bool get submitting => _submitting;
  String? get submitError => _submitError;

  /// Bắt đầu một phiên lập kế hoạch mới (khi Host gọi navigateTo('/plan/new...')).
  Future<void> start({String? presetSymbol}) async {
    final generation = ++_generation;
    _presetSymbol = presetSymbol?.trim().toUpperCase();
    _draft = const PlanDraft();
    _errors = const {};
    _validateOnChange = false;
    _submitting = false;
    _submitError = null;
    _loadError = null;
    _loadState = LoadState.loading;
    notifyListeners();

    try {
      final ctx = await _host.getLaunchContext();
      if (generation != _generation) return; // đã có phiên mới hơn
      final preset = _presetSymbol;
      _context = ctx;
      _draft = PlanDraft(
        acctNo: ctx.defaultAcctNo ??
            (ctx.subAccounts.isEmpty ? null : ctx.subAccounts.first.id),
        symbol: preset != null && ctx.symbols.contains(preset) ? preset : null,
      );
      _loadState = LoadState.ready;
    } on DcaHostException catch (e) {
      if (generation != _generation) return;
      _context = null;
      _loadError = e.message;
      _loadState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => start(presetSymbol: _presetSymbol);

  void setAcctNo(String? value) => _edit((d) => _copy(d, acctNo: value));
  void setSymbol(String value) => _edit((d) => _copy(d, symbol: value));
  void setInvestAmount(int? value) =>
      _edit((d) => _copy(d, investAmount: value, clearAmount: value == null));
  void setInvestDay(String value) => _edit((d) => _copy(d, investDay: value));
  void setOrderTime(String value) => _edit((d) => _copy(d, orderTime: value));
  void setOddLotAllow(bool value) => _edit((d) => _copy(d, oddLotAllow: value));

  /// Đổi chu kỳ thì reset "Lặp vào ngày" (giống handleCycleChange bên iBoard).
  void setInvestCycle(InvestCycle value) {
    if (value == _draft.investCycle) return;
    _edit((d) => _copy(d, investCycle: value, investDay: ''));
  }

  /// Validate rồi gửi kế hoạch cho Host App. Trả về null nếu không hợp lệ / bị từ chối.
  Future<SubmittedPlan?> submit() async {
    final ctx = _context;
    if (ctx == null || _submitting) return null;

    _validateOnChange = true;
    _submitError = null;
    _errors = PlanValidator.validate(_draft, context: ctx);
    if (_errors.isNotEmpty) {
      notifyListeners();
      return null;
    }

    final request = _draft.toRequest(context: ctx, createdAt: _clock());
    _submitting = true;
    notifyListeners();
    try {
      final result = await _host.submitPlan(request);
      return SubmittedPlan(request, result);
    } on DcaHostException catch (e) {
      _submitError = e.message;
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void _edit(PlanDraft Function(PlanDraft) change) {
    _draft = change(_draft);
    _submitError = null;
    final ctx = _context;
    if (_validateOnChange && ctx != null) {
      _errors = PlanValidator.validate(_draft, context: ctx);
    }
    notifyListeners();
  }

  static PlanDraft _copy(
    PlanDraft d, {
    String? acctNo,
    String? symbol,
    int? investAmount,
    bool clearAmount = false,
    InvestCycle? investCycle,
    String? investDay,
    String? orderTime,
    bool? oddLotAllow,
  }) =>
      PlanDraft(
        acctNo: acctNo ?? d.acctNo,
        symbol: symbol ?? d.symbol,
        investAmount: clearAmount ? null : (investAmount ?? d.investAmount),
        investCycle: investCycle ?? d.investCycle,
        investDay: investDay ?? d.investDay,
        orderTime: orderTime ?? d.orderTime,
        oddLotAllow: oddLotAllow ?? d.oddLotAllow,
      );
}
