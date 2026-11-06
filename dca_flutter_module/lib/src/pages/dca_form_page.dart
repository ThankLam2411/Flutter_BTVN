import 'package:flutter/material.dart';

import '../bridge/dca_host.dart';
import '../logic/dca_form_controller.dart';
import '../logic/plan_validator.dart';
import '../models/dca_models.dart';
import '../utils/formatters.dart';
import '../widgets/market_session_banner.dart';
import '../widgets/symbol_picker.dart';

/// Màn "Lập kế hoạch" – các trường giống form AutoTrading của iBoard:
/// Số tiểu khoản, Mã CK, Số tiền đầu tư, Chu kỳ lặp, Lặp vào ngày, Vào giờ, Tùy chọn đẩy lệnh.
class DcaFormPage extends StatefulWidget {
  const DcaFormPage({
    super.key,
    required this.controller,
    required this.host,
    required this.onCancel,
    required this.onSubmitted,
  });

  final DcaFormController controller;
  final DcaHost host;
  final Future<void> Function() onCancel;
  final void Function(SubmittedPlan plan) onSubmitted;

  @override
  State<DcaFormPage> createState() => _DcaFormPageState();
}

class _DcaFormPageState extends State<DcaFormPage> {
  late final TextEditingController _amountCtrl;

  DcaFormController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    final amount = _c.draft.investAmount;
    _amountCtrl =
        TextEditingController(text: amount == null ? '' : formatMoney(amount));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final submitted = await _c.submit();
    if (!mounted || submitted == null) return;
    widget.onSubmitted(submitted);
  }

  Future<void> _pickSymbol(LaunchContext ctx) async {
    final symbol = await showSymbolPicker(
      context,
      symbols: ctx.symbols,
      selected: _c.draft.symbol,
    );
    if (symbol != null) _c.setSymbol(symbol);
  }

  Future<void> _pickTime() async {
    final parts = _c.draft.orderTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.last) ?? 15,
      ),
      helpText: 'Giờ đặt lệnh (9:15–11:30, 13:00–14:30)',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) _c.setOrderTime(formatHm(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Đóng',
          onPressed: widget.onCancel,
        ),
        title: const Text('Đầu tư định kỳ'),
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => switch (_c.loadState) {
          LoadState.idle ||
          LoadState.loading =>
            const Center(child: CircularProgressIndicator()),
          LoadState.error => _ErrorView(
              message: _c.loadError ?? 'Không lấy được thông tin từ ứng dụng.',
              onRetry: _c.retry,
            ),
          LoadState.ready => _buildForm(context, _c.context!),
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, LaunchContext ctx) {
    final d = _c.draft;
    final errors = _c.errors;
    final textTheme = Theme.of(context).textTheme;
    final dayOptions = investDayOptions(d.investCycle);
    const gap = SizedBox(height: 16);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MarketSessionBanner(sessions: widget.host.marketSession),
          gap,
          Text('Lập kế hoạch', style: textTheme.titleLarge),
          Text('Lưu ký: ${ctx.custodyCd}  ·  Mã KH: ${ctx.custId}',
              style: textTheme.bodySmall),
          gap,

          // Số tiểu khoản*
          DropdownButtonFormField<String>(
            initialValue: d.acctNo,
            isExpanded: true,
            decoration: _decoration('Số tiểu khoản*',
                error: errors[PlanField.acctNo]),
            items: [
              for (final a in ctx.subAccounts)
                DropdownMenuItem(value: a.id, child: Text(a.display)),
            ],
            onChanged: _c.setAcctNo,
          ),
          gap,

          // Mã chứng khoán*
          InkWell(
            onTap: () => _pickSymbol(ctx),
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              isEmpty: d.symbol == null,
              decoration: _decoration('Mã chứng khoán*',
                  error: errors[PlanField.symbol],
                  hint: 'Chọn mã CK',
                  suffix: const Icon(Icons.arrow_drop_down)),
              child: d.symbol == null ? null : Text(d.symbol!),
            ),
          ),
          gap,

          // Số tiền đầu tư*
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            inputFormatters: const [ThousandsSeparatorInputFormatter()],
            decoration: _decoration('Số tiền đầu tư*',
                    error: errors[PlanField.investAmount], hint: '0')
                .copyWith(suffixText: 'VND'),
            onChanged: (text) => _c.setInvestAmount(parseMoney(text)),
          ),
          gap,

          // Chu kỳ lặp
          Text('Chu kỳ lặp', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<InvestCycle>(
            segments: [
              for (final cycle in InvestCycle.values)
                ButtonSegment(value: cycle, label: Text(cycle.label)),
            ],
            selected: {d.investCycle},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _c.setInvestCycle(s.first),
          ),
          gap,

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lặp vào ngày (disable khi chu kỳ = Hàng ngày)
              Expanded(
                child: DropdownButtonFormField<String>(
                  // key theo chu kỳ để reset giá trị khi đổi chu kỳ
                  key: ValueKey(d.investCycle),
                  initialValue: d.investDay.isEmpty ? null : d.investDay,
                  isExpanded: true,
                  decoration: _decoration('Lặp vào ngày',
                      error: errors[PlanField.investDay]),
                  hint: const Text('-- Chọn --'),
                  disabledHint: const Text('Mỗi ngày'),
                  items: [
                    for (final o in dayOptions)
                      DropdownMenuItem(value: o.value, child: Text(o.label)),
                  ],
                  onChanged: d.investCycle == InvestCycle.daily
                      ? null
                      : (v) => _c.setInvestDay(v ?? ''),
                ),
              ),
              const SizedBox(width: 12),
              // Vào giờ*
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: _decoration('Vào giờ*',
                        error: errors[PlanField.orderTime],
                        suffix: const Icon(Icons.schedule)),
                    child: Text(d.orderTime),
                  ),
                ),
              ),
            ],
          ),
          gap,

          // Tùy chọn đẩy lệnh
          DropdownButtonFormField<bool>(
            initialValue: d.oddLotAllow,
            isExpanded: true,
            decoration: _decoration('Tùy chọn đẩy lệnh'),
            items: const [
              DropdownMenuItem(
                  value: true, child: Text('Cho phép đặt lệnh lô lẻ')),
              DropdownMenuItem(
                  value: false, child: Text('Chỉ đặt lệnh lô chẵn')),
            ],
            onChanged: (v) => _c.setOddLotAllow(v ?? true),
          ),
          gap,

          if (_c.submitError != null) ...[
            _SubmitErrorCard(message: _c.submitError!),
            gap,
          ],

          FilledButton(
            onPressed: _c.submitting ? null : _submit,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            child: _c.submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Thiết lập'),
          ),
        ],
      ),
    );
  }

  static InputDecoration _decoration(
    String label, {
    String? error,
    String? hint,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        errorMaxLines: 2,
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
      );
}

class _SubmitErrorCard extends StatelessWidget {
  const _SubmitErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
