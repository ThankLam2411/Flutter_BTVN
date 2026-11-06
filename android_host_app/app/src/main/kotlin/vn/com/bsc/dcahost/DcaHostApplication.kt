package vn.com.bsc.dcahost

import android.app.Application
import vn.com.bsc.dcahost.flutter.DcaModule

class DcaHostApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Engine warm-up: khởi tạo & chạy FlutterEngine ngay khi app mở và lưu vào FlutterEngineCache,
        // để lần đầu bấm "Đầu tư định kỳ" không bị màn trắng / chờ khởi tạo Dart VM.
        DcaModule.warmUp(this)
    }
}
