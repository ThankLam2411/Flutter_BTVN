package vn.com.bsc.dcahost.flutter

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.util.Calendar
import java.util.TimeZone

/**
 * EventChannel stream trạng thái phiên giao dịch sang Flutter.
 * onListen: Flutter có subscriber => bắt đầu tick 5s. onCancel: Flutter huỷ (màn ẩn/đóng) => dừng.
 * Dữ liệu gửi dạng Map qua StandardMessageCodec; thời gian là timestamp UTC (Long).
 */
class MarketSessionStreamHandler : EventChannel.StreamHandler {
    companion object {
        const val CHANNEL_NAME = "vn.com.bsc.dca/market_session"
        private const val INTERVAL_MS = 5_000L
        private const val TAG = "MarketSession"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private val tick = object : Runnable {
        override fun run() {
            emit()
            handler.postDelayed(this, INTERVAL_MS)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        handler.removeCallbacks(tick)
        tick.run()
        Log.d(TAG, "onListen")
    }

    override fun onCancel(arguments: Any?) {
        handler.removeCallbacks(tick)
        sink = null
        Log.d(TAG, "onCancel")
    }

    private fun emit() {
        val now = System.currentTimeMillis()
        val (code, label) = sessionAt(now)
        sink?.success(mapOf("code" to code, "label" to label, "serverTimeMillis" to now))
    }

    /** Phiên giao dịch HOSE theo giờ Việt Nam. */
    private fun sessionAt(millis: Long): Pair<String, String> {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"))
        cal.timeInMillis = millis
        val weekday = cal.get(Calendar.DAY_OF_WEEK)
        if (weekday == Calendar.SATURDAY || weekday == Calendar.SUNDAY) return "CLOSED" to "Nghỉ cuối tuần"
        val m = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        return when {
            m < 540 -> "PRE_OPEN" to "Chưa mở cửa"
            m < 555 -> "ATO" to "Phiên ATO"
            m < 690 -> "CONTINUOUS" to "Khớp lệnh liên tục (sáng)"
            m < 780 -> "BREAK" to "Nghỉ trưa"
            m < 870 -> "CONTINUOUS" to "Khớp lệnh liên tục (chiều)"
            m < 885 -> "ATC" to "Phiên ATC"
            else -> "CLOSED" to "Đã đóng cửa"
        }
    }
}
