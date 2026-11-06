// Schema Pigeon cho giao tiếp Flutter Module <-> iOS Host App.
//
// Sinh code:  dart run pigeon --input pigeons/dca_messages.dart
//   (hoặc ./tool/gen_pigeon.sh)
//
// Quy ước:
//  - Chỉ dùng các kiểu StandardMessageCodec hỗ trợ (String, int, bool, List, Map, enum, class).
//  - KHÔNG dùng DateTime -> gửi timestamp UTC (millisecondsSinceEpoch).
//  - int Dart <-> Int64 Swift.
//  - Đây là implementation detail của module: UI/logic Dart không import trực tiếp file .g.dart,
//    chỉ lớp PigeonDcaHost (lib/src/bridge) map sang model nội bộ.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeons/dca_messages.g.dart',
    dartOptions: DartOptions(),
    // Host App iOS implement DcaHostApi và gọi DcaFlutterApi => file Swift sinh thẳng vào project iOS.
    swiftOut: '../ios_host_app/DcaHost/Bridge/DcaMessages.g.swift',
    swiftOptions: SwiftOptions(),
    // Host App Android implement DcaHostApi và gọi DcaFlutterApi => file Kotlin sinh thẳng vào project Android.
    kotlinOut:
        '../android_host_app/app/src/main/kotlin/vn/com/bsc/dcahost/bridge/DcaMessages.g.kt',
    kotlinOptions: KotlinOptions(package: 'vn.com.bsc.dcahost.bridge'),
    dartPackageName: 'dca_flutter_module',
  ),
)
// ---------------------------------------------------------------------------
// Enum & data class
// ---------------------------------------------------------------------------

enum DcaInvestCycle { daily, weekly, monthly }

enum DcaFlowStatus { submitted, cancelled }

class DcaSubAccount {
  DcaSubAccount({required this.id, required this.type});

  String id;
  String type;
}
class DcaLaunchContext {
  DcaLaunchContext({
    required this.custodyCd,
    required this.custId,
    required this.subAccounts,
    this.defaultAcctNo,
    required this.symbols,
  });

  String custodyCd;
  String custId;
  List<DcaSubAccount> subAccounts;
  String? defaultAcctNo;

  List<String> symbols;
}

class DcaPlanRequest {
  DcaPlanRequest({
    required this.acctNo,
    required this.custodyCd,
    required this.custId,
    required this.symbol,
    required this.investAmount,
    required this.investCycle,
    required this.investDay,
    required this.orderTime,
    required this.oddLotAllow,
    required this.createdAtMillis,
  });

  String acctNo;
  String custodyCd;
  String custId;
  String symbol;

  int investAmount;
  DcaInvestCycle investCycle;

  String investDay;

  String orderTime;

  bool oddLotAllow;

  int createdAtMillis;
}

class DcaSubmitResult {
  DcaSubmitResult({required this.quoteId, required this.message});

  String quoteId;
  String message;
}

class DcaFlowResult {
  DcaFlowResult({required this.status, this.plan, this.quoteId});

  DcaFlowStatus status;
  DcaPlanRequest? plan;
  String? quoteId;
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

/// Flutter -> iOS.
@HostApi()
abstract class DcaHostApi {
  void flutterReady();

  DcaLaunchContext getLaunchContext();

  @async
  DcaSubmitResult submitPlan(DcaPlanRequest request);

  void finish(DcaFlowResult result);
}

@FlutterApi()
abstract class DcaFlutterApi {
  void navigateTo(String route);
}
