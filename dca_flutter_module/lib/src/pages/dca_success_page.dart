import 'package:flutter/material.dart';

import '../models/dca_models.dart';
import '../utils/formatters.dart';

/// Kết quả sau khi Host App đã nhận kế hoạch. "Hoàn tất" => HostApi.finish(submitted).
class DcaSuccessPage extends StatefulWidget {
  const DcaSuccessPage({super.key, required this.plan, required this.onDone});

  final SubmittedPlan plan;
  final Future<void> Function() onDone;

  @override
  State<DcaSuccessPage> createState() => _DcaSuccessPageState();
}

class _DcaSuccessPageState extends State<DcaSuccessPage> {
  bool _closing = false;

  Future<void> _done() async {
    if (_closing) return;
    setState(() => _closing = true);
    await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan.request;
    final r = widget.plan.result;
    final textTheme = Theme.of(context).textTheme;
    final rows = <(String, String)>[
      ('Mã kế hoạch', r.quoteId),
      ('Số tiểu khoản', p.acctNo),
      ('Mã chứng khoán', p.symbol),
      ('Số tiền đầu tư', '${formatMoney(p.investAmount)} VND'),
      ('Chu kỳ lặp', p.investCycle.label),
      ('Lặp vào ngày', investDayLabel(p.investCycle, p.investDay)),
      ('Vào giờ', p.orderTime),
      (
        'Tùy chọn đẩy lệnh',
        p.oddLotAllow ? 'Cho phép đặt lệnh lô lẻ' : 'Chỉ đặt lệnh lô chẵn'
      ),
      ('Ngày tạo', formatDateTime(p.createdAt)),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Thiết lập thành công'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Icon(Icons.check_circle,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(r.message,
                  textAlign: TextAlign.center, style: textTheme.titleMedium),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    for (final (label, value) in rows)
                      ListTile(
                        dense: true,
                        title: Text(label),
                        trailing: Text(value,
                            style: textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _closing ? null : _done,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Hoàn tất – quay về ứng dụng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
