package vn.com.bsc.dcahost.flutter

import vn.com.bsc.dcahost.bridge.DcaInvestCycle
import vn.com.bsc.dcahost.bridge.DcaPlanRequest
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

// Hiển thị dữ liệu nhận từ Flutter Module trên UI native.

private val weekdayLabels = mapOf(
    "monday" to "Thứ Hai", "tuesday" to "Thứ Ba", "wednesday" to "Thứ Tư",
    "thursday" to "Thứ Năm", "friday" to "Thứ Sáu",
)

val DcaInvestCycle.label: String
    get() = when (this) {
        DcaInvestCycle.DAILY -> "Hàng ngày"
        DcaInvestCycle.WEEKLY -> "Hàng tuần"
        DcaInvestCycle.MONTHLY -> "Hàng tháng"
    }

val DcaPlanRequest.investDayLabel: String
    get() = when (investCycle) {
        DcaInvestCycle.DAILY -> "mỗi ngày"
        DcaInvestCycle.WEEKLY -> weekdayLabels[investDay] ?: investDay
        DcaInvestCycle.MONTHLY -> "ngày $investDay"
    }

val DcaPlanRequest.amountText: String
    get() = NumberFormat.getNumberInstance(Locale.US).format(investAmount) + " VND"

/** createDate theo định dạng iBoard: dd/MM/yyyy HH:mm:ss (từ timestamp UTC). */
val DcaPlanRequest.createDateText: String
    get() = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.US)
        .apply { timeZone = TimeZone.getTimeZone("Asia/Ho_Chi_Minh") }
        .format(Date(createdAtMillis))

val DcaPlanRequest.oddLotText: String
    get() = if (oddLotAllow) "Cho phép lô lẻ" else "Chỉ lô chẵn"

val DcaPlanRequest.summary: String
    get() = "$symbol · $amountText · ${investCycle.label} ($investDayLabel) lúc $orderTime"

val DcaPlanRequest.detailText: String
    get() = """
        Tiểu khoản: $acctNo
        Mã CK: $symbol
        Số tiền: $amountText
        Chu kỳ: ${investCycle.label} – $investDayLabel
        Vào giờ: $orderTime
        Tùy chọn: $oddLotText
        Ngày tạo: $createDateText
    """.trimIndent()
