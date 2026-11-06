package vn.com.bsc.dcahost.flutter

import android.os.Handler
import android.os.Looper
import vn.com.bsc.dcahost.bridge.DcaFlowResult
import vn.com.bsc.dcahost.bridge.DcaHostApi
import vn.com.bsc.dcahost.bridge.DcaLaunchContext
import vn.com.bsc.dcahost.bridge.DcaPlanRequest
import vn.com.bsc.dcahost.bridge.DcaSubmitResult
import vn.com.bsc.dcahost.bridge.FlutterError
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Implement Pigeon DcaHostApi (Flutter -> Android). Interface sinh từ pigeons/dca_messages.dart.
 * Các hàm được gọi trên main thread.
 */
class DcaHostApiImpl : DcaHostApi {
    var currentContext: DcaLaunchContext? = null

    /** Giả lập danh sách mã bị hạn chế giao dịch phía server. */
    private val restrictedSymbols = setOf("ROS")
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun flutterReady() {
        DcaModule.handleFlutterReady()
    }

    override fun getLaunchContext(): DcaLaunchContext =
        // FlutterError => Dart nhận PlatformException(code: "NO_SESSION", ...)
        currentContext ?: throw FlutterError("NO_SESSION", "Bạn chưa đăng nhập!", null)

    /**
     * @async: trả kết quả qua callback. LUÔN gọi callback đúng 1 lần,
     * nếu không phía Flutter sẽ await mãi mãi.
     */
    override fun submitPlan(request: DcaPlanRequest, callback: (Result<DcaSubmitResult>) -> Unit) {
        // Giả lập gọi API AutotradeAction (PLACE_ORDER) mất ~0.8s.
        mainHandler.postDelayed({
            if (request.symbol in restrictedSymbols) {
                callback(
                    Result.failure(
                        FlutterError(
                            "SYMBOL_RESTRICTED",
                            "Mã ${request.symbol} đang bị hạn chế giao dịch, không thể lập kế hoạch.",
                            null,
                        ),
                    ),
                )
                return@postDelayed
            }
            val result = DcaSubmitResult(
                quoteId = "DCA" + SimpleDateFormat("yyyyMMddHHmmss", Locale.US).format(Date()),
                message = "Ứng dụng Android đã nhận kế hoạch đầu tư định kỳ.",
            )
            DcaModule.handlePlanReceived(request, result)
            callback(Result.success(result))
        }, 800)
    }

    override fun finish(result: DcaFlowResult) {
        DcaModule.handleFinish(result)
    }
}
