# BTVN – Flutter Module "Đầu tư định kỳ" (DCA) nhúng vào app iOS

Flutter Module cho phép khách hàng **lập kế hoạch đầu tư định kỳ** (các trường giống tính năng
AutoTrading trên iBoard-BSC). Module được nhúng vào **app iOS native (UIKit)** bằng **XCFramework**.
App iOS truyền thông tin khách hàng vào Module và **nhận lại kế hoạch** người dùng đã nhập.

```
BT/
├── dca_flutter_module/          # Flutter Module (flutter create --template=module)
│   ├── pigeons/dca_messages.dart        # Schema Pigeon (HostApi + FlutterApi)
│   ├── lib/
│   │   ├── main.dart                    # main() (mock, chạy độc lập) + dcaPlanMain() (entrypoint cho iOS)
│   │   └── src/
│   │       ├── bridge/                  # DcaHost (interface), PigeonDcaHost (thật), MockDcaHost (giả lập)
│   │       ├── pigeons/                 # dca_messages.g.dart  (Pigeon sinh ra)
│   │       ├── logic/                   # DcaFormController, PlanValidator
│   │       ├── models/  pages/  widgets/  utils/
│   ├── test/                            # unit test validator, formatter, controller
│   └── tool/gen_pigeon.sh, tool/build_ios_framework.sh
├── android_host_app/            # App Android host (Kotlin + XML), tích hợp bằng AAR
│   ├── settings.gradle.kts              # maven repo AAR local + download.flutter.io
│   ├── app/build.gradle.kts             # debug/profile/releaseImplementation(...:flutter_xxx:1.0)
│   └── app/src/main/kotlin/vn/com/bsc/dcahost/
│       ├── DcaHostApplication.kt        # warm-up engine + FlutterEngineCache khi mở app
│       ├── MainActivity.kt              # nút mở Module + danh sách kế hoạch nhận được
│       ├── MockUserSession.kt
│       ├── bridge/DcaMessages.g.kt      # Pigeon sinh ra
│       └── flutter/                     # DcaModule, DcaFlutterActivity, DcaHostApiImpl, MarketSessionStreamHandler
└── ios_host_app/                # App iOS host (UIKit)
    ├── project.yml                      # XcodeGen spec
    └── DcaHost/
        ├── AppDelegate.swift            # warm-up engine khi mở app
        ├── HomeViewController.swift     # nút mở Module + danh sách kế hoạch nhận được
        ├── MockUserSession.swift        # dữ liệu khách hàng giả lập
        ├── Bridge/DcaMessages.g.swift   # Pigeon sinh ra
        └── Flutter/
            ├── DcaModule.swift                  # quản lý Engine, mở/đóng Module, điều hướng
            ├── DcaHostApiImpl.swift             # implement Pigeon HostApi
            ├── MarketSessionStreamHandler.swift # EventChannel stream phiên giao dịch
            ├── DcaFlutterViewController.swift
            └── DcaPlan+Display.swift
```

## 1. Nghiệp vụ

Các trường lấy theo `AutoTrading.tsx` / `PlanDetailDto` của iBoard:

| Trường | Giá trị | Quy tắc (giống iBoard) |
|---|---|---|
| Số tiểu khoản* | `acctNo` – danh sách App iOS truyền sang | bắt buộc |
| Mã chứng khoán* | `symbol` – danh sách App iOS truyền sang | bắt buộc, phải có trong danh sách |
| Số tiền đầu tư* | `investAmount` (VND), tự format `1,000,000` | > 0 |
| Chu kỳ lặp | `investCycle`: `daily` / `weekly` / `monthly` | đổi chu kỳ thì reset ngày lặp |
| Lặp vào ngày | `investDay`: `''` / `monday..friday` / `1..31` | bắt buộc với weekly, monthly |
| Vào giờ* | `orderTime` `HH:mm` (mặc định 09:15) | 09:15–11:30 hoặc 13:00–14:30 |
| Tùy chọn đẩy lệnh | `oddLotAllow`: lô lẻ / chỉ lô chẵn | |
| (tự động) | `custodyCd`, `custId`, `createdAtMillis` | lấy từ App / thời điểm tạo |

Luồng: **Native Home → Flutter (form → thành công) → quay về Native**, App hiển thị kế hoạch nhận được.
Để demo lỗi từ Host: chọn mã **ROS** → App iOS từ chối bằng `PigeonError("SYMBOL_RESTRICTED")`.

```
 iOS Host App                                   Flutter Module (engine "dca_engine")
 ────────────                                   ─────────────────────────────────────
 AppDelegate: warmUp() ── run("dcaPlanMain") ─► main isolate, đăng ký DcaFlutterApi
                       ◄─ HostApi.flutterReady() ─┘
 Bấm "Đầu tư định kỳ"
   FlutterApi.navigateTo("/plan/new?symbol=FPT") ─► reset form, mở route
   present(DcaFlutterViewController)
                       ◄─ HostApi.getLaunchContext()   (lấy Arguments: KH, tiểu khoản, mã)
 EventChannel market_session ═══ stream ═════════► banner trạng thái phiên
                       ◄─ HostApi.submitPlan(plan)  @async  (Host nhận dữ liệu / hoặc PigeonError)
                       ◄─ HostApi.finish(result)        (submitted | cancelled)
 dismiss, engine.viewController = nil, hiển thị kế hoạch
```

## 2. Phần 2 – Interop (Module 05, 06)

| Nội dung slide | Thể hiện ở |
|---|---|
| **Pigeon** – schema bằng Dart, sinh code type-safe Dart/Swift | `pigeons/dca_messages.dart` → `dca_messages.g.dart`, `DcaMessages.g.swift` |
| `@HostApi` (Flutter → Platform) | `DcaHostApi`: `flutterReady`, `getLaunchContext`, `submitPlan`, `finish` – implement ở `DcaHostApiImpl.swift` |
| `@FlutterApi` (Platform → Flutter) | `DcaFlutterApi.navigateTo(route)` – gọi ở `DcaModule.navigate(to:)` |
| `@async` + complex object | `submitPlan(DcaPlanRequest) -> DcaSubmitResult`, trả qua `completion` (luôn gọi đúng 1 lần) |
| Exception propagation | Swift `PigeonError(code, message)` → Dart `PlatformException` → `DcaHostException` (`PigeonDcaHost._guard`) → hiển thị trên form |
| Codec / kiểu dữ liệu | enum, class lồng nhau, `List<DcaSubAccount>`; **không dùng DateTime** → `createdAtMillis` (UTC); `int` ↔ `Int64` |
| **EventChannel** stream Platform → Flutter | `MarketSessionStreamHandler.swift` (`onListen` / `onCancel`, gửi `Map`) ↔ `MarketSessionBanner` (`receiveBroadcastStream`) |
| Code Pigeon là implementation detail | Chỉ `PigeonDcaHost` import `.g.dart`; UI/logic dùng model nội bộ qua interface `DcaHost` (có `MockDcaHost` để chạy độc lập & test) |

## 3. Phần 3 – Add to App (Module 09, 11, 12)

| Nội dung slide | Thể hiện ở |
|---|---|
| Flutter Module vs App (`--template=module`, `.ios/` không commit) | `pubspec.yaml` (`flutter: module:`), `.gitignore` |
| `dartEntryPoint` riêng | `@pragma('vm:entry-point') dcaPlanMain()` trong `lib/main.dart`; iOS: `engine.run(withEntrypoint: "dcaPlanMain")` |
| Build **XCFramework** & tích hợp vào Xcode | `tool/build_ios_framework.sh` → `ios_host_app/Flutter/{Debug,Release}`; `project.yml` (link, Embed & Sign, `FRAMEWORK_SEARCH_PATHS = .../$(CONFIGURATION)`) |
| Engine warm-up / tái sử dụng engine | `AppDelegate` gọi `DcaModule.shared.warmUp()`; 1 `FlutterEngine` dùng cho mọi lần mở |
| Nhúng qua `FlutterViewController` (explicit engine) | `DcaFlutterViewController(engine:nibName:bundle:)`, present full screen |
| Tránh memory leak khi push/pop | `engine.viewController = nil` sau khi dismiss; `[weak self]` trong closure; `weak var module`; log `deinit` |
| Chỉ gửi FlutterApi khi Flutter đã sẵn sàng | `HostApi.flutterReady()` + `pendingRoute` trong `DcaModule` |
| Truyền Arguments & nhận kết quả khi đóng Module | route có `?symbol=` (FlutterApi) → Flutter tự lấy `getLaunchContext()` (HostApi) → trả `DcaFlowResult` qua `finish()` |
| Lifecycle sync | `FlutterViewController` tự forward lifecycle; `AppLifecycleListener` trong `MarketSessionBanner` huỷ/đăng ký lại stream khi ẩn/hiện → iOS dừng Timer ở `onCancel` |
| Initial route / navigation trong Module | `DcaRoutes`, `onGenerateInitialRoutes`, `pushNamedAndRemoveUntil` theo route Host gửi |

### Android (Module 10)

| Nội dung slide | Thể hiện ở |
|---|---|
| Build **AAR** (Maven repo local) | `tool/build_aar.sh` → `build/host/outputs/repo`; `settings.gradle.kts` khai báo repo; `debugImplementation/profileImplementation/releaseImplementation("vn.com.bsc.dca_flutter_module:flutter_xxx:1.0")` + build type `profile` |
| **FlutterEngineCache** + warm-up | `DcaHostApplication.onCreate` → `DcaModule.warmUp()` chạy entrypoint `dcaPlanMain`, `FlutterEngineCache.put("dca_engine", engine)` |
| Nhúng qua **FlutterActivity** (cached engine) | `DcaFlutterActivity`: `getCachedEngineId()`, `shouldDestroyEngineWithHost() = false` |
| Pigeon trên Android | `DcaHostApiImpl.kt` implement `DcaHostApi`; lỗi bằng `FlutterError(code, message)`; `DcaFlutterApi.navigateTo` |
| EventChannel | `MarketSessionStreamHandler.kt` (Handler tick 5s, dừng ở `onCancel`) |
| Tránh leak / đồng bộ đóng màn | `WeakReference` tới Activity; nút Back hệ thống thoát mà Flutter chưa `finish()` → Host vẫn nhận `CANCELLED` |

## 4a. Chạy Android (Windows/macOS/Linux)

```bash
cd BT/dca_flutter_module
sh tool/gen_pigeon.sh        # sinh .g.dart / .g.swift / .g.kt (đã sinh sẵn trong repo)
sh tool/build_aar.sh --no-profile --no-release   # => build/host/outputs/repo (debug cho nhanh)
cd ../android_host_app
echo "sdk.dir=E:/dev/android-sdk" > local.properties   # đường dẫn Android SDK, dùng dấu /
./gradlew installDebug       # cần emulator/thiết bị đang chạy (adb devices)
adb shell am start -n vn.com.bsc.dcahost/.MainActivity
```

Đã chạy thử trên emulator Android 15 (API 35, x86_64) với Flutter 3.47.9, AGP 8.11.1, Kotlin 2.2, Gradle 8.14.3:
mở Module với mã gợi ý FPT → validate → submit → Host nhận kế hoạch; mã ROS → lỗi từ Host;
Back hệ thống → Host nhận `CANCELLED`, EventChannel `onCancel`. Mở lần 2 (engine cache): ~0.36 s.

> APK debug khá nặng (~800 MB) vì `libflutter.so` bản debug còn symbol. Bản release (`build_aar.sh` đủ 3 biến thể + `assembleRelease`) nhỏ hơn nhiều.

## 4. Chạy thử iOS (cần macOS + Xcode + Flutter SDK)

```bash
# 1) Sinh code Pigeon (Dart + Swift) – commit cả 2 file .g sau khi sinh
cd BT/dca_flutter_module
sh tool/gen_pigeon.sh

# 2) Test & analyze
flutter test
flutter analyze

# 3) (tuỳ chọn) Chạy Module độc lập với MockDcaHost
flutter run

# 4) Build XCFramework vào ../ios_host_app/Flutter
sh tool/build_ios_framework.sh

# 5) Sinh project Xcode và chạy app host
cd ../ios_host_app
brew install xcodegen   # nếu chưa có
xcodegen generate
open DcaHost.xcodeproj  # chọn simulator/device -> Run
```

> Phải chạy bước 1 trước bước 5, vì `DcaHost/Bridge/DcaMessages.g.swift` do Pigeon sinh ra.

**Debug Dart trong app host:** chạy app từ Xcode (cấu hình Debug), rồi trong `dca_flutter_module` chạy `flutter attach`.

### Tích hợp XCFramework thủ công (nếu không dùng XcodeGen)

1. Tạo iOS App (UIKit, Swift) tên `DcaHost`, copy thư mục `DcaHost/` vào, xoá SceneDelegate/Main.storyboard mặc định (app dùng `AppDelegate` + `window`).
2. *Build Phases › Link Binary With Libraries* › **+** › *Add Other* › chọn `Flutter/Release/App.xcframework`, `Flutter.xcframework`, `FlutterPluginRegistrant.xcframework`.
3. *Build Settings › Framework Search Paths*: `$(inherited)` và `$(PROJECT_DIR)/Flutter/$(CONFIGURATION)`.
4. *General › Frameworks, Libraries, and Embedded Content*: **Embed & Sign** cho mọi framework trừ `FlutterPluginRegistrant`.
5. *Build Settings*: `ENABLE_USER_SCRIPT_SANDBOXING = No`.

## 5. Ghi chú

- `pigeon: ^22.6.0`, nên phía Swift implement `@async` theo kiểu **completion handler**. Nếu dùng bản Pigeon mới hơn mà sinh ra chữ ký khác (vd. `async throws`), sửa `DcaHostApiImpl.submitPlan` cho khớp protocol sinh ra.
- Module không dùng plugin bên thứ 3, nên XCFramework gọn và không bị trùng thư viện native với app host.
- Dữ liệu khách hàng và phản hồi submit đều là **giả lập** (`MockUserSession`, `DcaHostApiImpl`). App thật sẽ gọi API `AutotradeAction` + xác thực OTP như iBoard.
