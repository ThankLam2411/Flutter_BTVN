import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Engine warm-up: khởi tạo & chạy FlutterEngine ngay khi app mở,
        // để lần đầu bấm "Đầu tư định kỳ" không bị màn trắng / chờ khởi tạo Dart VM.
        DcaModule.shared.warmUp()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: HomeViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
