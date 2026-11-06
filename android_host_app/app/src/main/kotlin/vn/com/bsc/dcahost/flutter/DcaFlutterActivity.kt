package vn.com.bsc.dcahost.flutter

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

/**
 * Màn hình Flutter của Module, dùng engine đã warm-up trong [io.flutter.embedding.engine.FlutterEngineCache].
 * FlutterActivity tự forward lifecycle (onResume/onPause/onStop…) vào Engine => Dart nhận AppLifecycleState.
 */
class DcaFlutterActivity : FlutterActivity() {

    /** Dùng engine cache thay vì tạo engine mới mỗi lần mở. */
    override fun getCachedEngineId(): String = DcaModule.ENGINE_ID

    /** Engine sống tiếp sau khi Activity đóng để lần sau mở ngay. */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Trường hợp process bị kill rồi Android khôi phục Activity: engine cache chưa có.
        DcaModule.warmUp(this)
        super.onCreate(savedInstanceState)
        if (!DcaModule.hasActiveSession) {
            // Không có phiên mở hợp lệ từ Host (vd. khôi phục sau process death) => đóng.
            finish()
            return
        }
        DcaModule.attach(this)
    }

    override fun onDestroy() {
        DcaModule.detach(this, isFinishing)
        super.onDestroy()
        Log.d("DcaFlutterActivity", "onDestroy – Activity tách khỏi engine, engine vẫn trong cache")
    }
}
