package vn.com.bsc.dcahost.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import vn.com.bsc.dcahost.bridge.DcaFlowResult
import vn.com.bsc.dcahost.bridge.DcaFlowStatus
import vn.com.bsc.dcahost.bridge.DcaFlutterApi
import vn.com.bsc.dcahost.bridge.DcaHostApi
import vn.com.bsc.dcahost.bridge.DcaLaunchContext
import vn.com.bsc.dcahost.bridge.DcaPlanRequest
import vn.com.bsc.dcahost.bridge.DcaSubmitResult
import java.lang.ref.WeakReference

/**
 * Cửa ngõ duy nhất của Host App Android tới Flutter Module "Đầu tư định kỳ".
 *
 * - Warm-up 1 FlutterEngine (entrypoint `dcaPlanMain`) và lưu vào [FlutterEngineCache].
 * - Đăng ký Pigeon DcaHostApi + EventChannel trên engine.
 * - Điều hướng Native -> Flutter (DcaFlutterApi.navigateTo) và nhận kết quả khi Flutter đóng.
 */
object DcaModule {
    private const val TAG = "DcaModule"
    const val ENGINE_ID = "dca_engine"

    /** Trùng tên hàm @pragma('vm:entry-point') trong lib/main.dart của Module. */
    private const val DART_ENTRYPOINT = "dcaPlanMain"
    private const val NEW_PLAN_ROUTE = "/plan/new"

    private val hostApi = DcaHostApiImpl()
    private val marketSessionHandler = MarketSessionStreamHandler()
    private var flutterApi: DcaFlutterApi? = null

    /** Flutter đã gọi HostApi.flutterReady() => handler FlutterApi đã sẵn sàng. */
    private var isFlutterReady = false
    private var pendingRoute: String? = null

    /** WeakReference: không giữ Activity sau khi nó bị huỷ (tránh leak). */
    private var activityRef: WeakReference<DcaFlutterActivity>? = null
    private var callback: ((DcaFlowResult) -> Unit)? = null

    /** Host nhận kế hoạch ngay khi Flutter submit (trước khi đóng màn hình). */
    var onPlanReceived: ((DcaPlanRequest, DcaSubmitResult) -> Unit)? = null

    val hasActiveSession: Boolean get() = callback != null

    // region Engine

    fun warmUp(context: Context) {
        if (FlutterEngineCache.getInstance().contains(ENGINE_ID)) return

        val engine = FlutterEngine(context.applicationContext)
        val messenger = engine.dartExecutor.binaryMessenger

        // Đăng ký handler trước khi chạy Dart để không lỡ message nào.
        DcaHostApi.setUp(messenger, hostApi)
        flutterApi = DcaFlutterApi(messenger)
        EventChannel(messenger, MarketSessionStreamHandler.CHANNEL_NAME)
            .setStreamHandler(marketSessionHandler)

        isFlutterReady = false
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                DART_ENTRYPOINT,
            ),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        Log.d(TAG, "Engine warmed up ($DART_ENTRYPOINT)")
    }

    // endregion

    // region Mở / đóng Module

    /**
     * Mở luồng lập kế hoạch đầu tư định kỳ.
     * @param context Arguments – Flutter hỏi qua HostApi.getLaunchContext().
     * @param presetSymbol mã CK gợi ý, truyền qua route `/plan/new?symbol=...`.
     * @param onResult kết quả khi Flutter gọi finish() (hoặc người dùng bấm Back thoát).
     */
    fun open(
        activity: Activity,
        context: DcaLaunchContext,
        presetSymbol: String?,
        onResult: (DcaFlowResult) -> Unit,
    ) {
        warmUp(activity)
        if (activityRef?.get() != null) return

        hostApi.currentContext = context
        callback = onResult
        navigate(buildRoute(presetSymbol))
        activity.startActivity(Intent(activity, DcaFlutterActivity::class.java))
    }

    private fun buildRoute(presetSymbol: String?): String {
        val symbol = presetSymbol?.trim()?.uppercase()
        if (symbol.isNullOrEmpty()) return NEW_PLAN_ROUTE
        return Uri.Builder().path(NEW_PLAN_ROUTE)
            .appendQueryParameter("symbol", symbol).build().toString()
    }

    private fun navigate(route: String) {
        val api = flutterApi
        // Chỉ gọi FlutterApi khi Flutter đã đăng ký handler, nếu không message sẽ bị mất.
        if (!isFlutterReady || api == null) {
            pendingRoute = route
            return
        }
        api.navigateTo(route) { result ->
            result.exceptionOrNull()?.let { Log.w(TAG, "navigateTo($route) lỗi", it) }
        }
    }

    // endregion

    // region Gọi từ DcaHostApiImpl (Flutter -> Host)

    internal fun handleFlutterReady() {
        isFlutterReady = true
        pendingRoute?.let {
            pendingRoute = null
            navigate(it)
        }
    }

    internal fun handlePlanReceived(plan: DcaPlanRequest, result: DcaSubmitResult) {
        onPlanReceived?.invoke(plan, result)
    }

    internal fun handleFinish(result: DcaFlowResult) {
        deliver(result)
        activityRef?.get()?.finish()
    }

    // endregion

    // region Gọi từ DcaFlutterActivity

    internal fun attach(activity: DcaFlutterActivity) {
        activityRef = WeakReference(activity)
    }

    internal fun detach(activity: DcaFlutterActivity, isFinishing: Boolean) {
        if (activityRef?.get() === activity) activityRef = null
        // Người dùng thoát bằng nút Back hệ thống mà Flutter chưa gọi finish() => coi như huỷ.
        if (isFinishing) deliver(DcaFlowResult(status = DcaFlowStatus.CANCELLED))
    }

    private fun deliver(result: DcaFlowResult) {
        val cb = callback ?: return
        callback = null
        hostApi.currentContext = null
        cb(result)
    }

    // endregion
}
