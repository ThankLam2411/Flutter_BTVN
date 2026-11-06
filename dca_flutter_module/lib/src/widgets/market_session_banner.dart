import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dca_models.dart';
import '../utils/formatters.dart';

/// Hiển thị trạng thái phiên giao dịch do app iOS stream sang qua EventChannel.
///
/// Lifecycle Sync: khi màn Flutter bị ẩn (Host present màn khác / app xuống background)
/// thì huỷ subscription => phía iOS nhận onCancel và dừng Timer, tránh tốn tài nguyên.
class MarketSessionBanner extends StatefulWidget {
  const MarketSessionBanner({super.key, required this.sessions});

  final Stream<MarketSession> Function() sessions;

  @override
  State<MarketSessionBanner> createState() => _MarketSessionBannerState();
}

class _MarketSessionBannerState extends State<MarketSessionBanner> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<MarketSession>? _sub;
  MarketSession? _latest;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onShow: _subscribe,
      onHide: _unsubscribe,
    );
    _subscribe();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    if (_sub != null) return;
    _sub = widget.sessions().listen(
      (s) => setState(() {
        _latest = s;
        _error = null;
      }),
      onError: (Object e) => setState(() {
        _error = e is DcaHostException ? e.message : '$e';
      }),
    );
  }

  void _unsubscribe() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = _latest;
    final title = _error ??
        (latest == null ? 'Đang lấy trạng thái phiên…' : latest.label);
    final subtitle = latest == null
        ? 'Stream từ app qua EventChannel'
        : '${latest.code} · cập nhật ${formatHms(latest.serverTime)} (EventChannel)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_filled, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer)),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
