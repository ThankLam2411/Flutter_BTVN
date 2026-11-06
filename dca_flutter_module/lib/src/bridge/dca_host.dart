import '../models/dca_models.dart';

/// Mọi giao tiếp với Host App đi qua interface này.
///
/// - [PigeonDcaHost]: bản thật, nói chuyện với iOS qua Pigeon + EventChannel.
/// - [MockDcaHost]:   bản giả lập để chạy Module độc lập (`flutter run`) và viết test.
abstract interface class DcaHost {
  /// Route Host yêu cầu mở (FlutterApi.navigateTo).
  Stream<String> get routeRequests;

  /// Báo cho Host: Flutter đã sẵn sàng nhận FlutterApi.
  Future<void> notifyReady();

  /// Arguments khi mở Module.
  Future<LaunchContext> getLaunchContext();

  /// Gửi kế hoạch; ném [DcaHostException] nếu Host từ chối.
  Future<SubmitResult> submitPlan(PlanRequest request);

  /// Đóng Module, trả kết quả đã lập kế hoạch.
  Future<void> finishSubmitted(SubmittedPlan plan);

  /// Đóng Module, người dùng huỷ.
  Future<void> finishCancelled();

  /// Stream trạng thái phiên giao dịch (EventChannel). Mỗi lần gọi là một subscription mới.
  Stream<MarketSession> marketSession();
}
