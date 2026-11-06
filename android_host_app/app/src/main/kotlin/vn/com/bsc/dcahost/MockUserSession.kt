package vn.com.bsc.dcahost

import vn.com.bsc.dcahost.bridge.DcaLaunchContext
import vn.com.bsc.dcahost.bridge.DcaSubAccount

/** Phiên đăng nhập giả lập của Host App (thực tế lấy từ module Auth của app). */
object MockUserSession {
    const val CUSTODY_CD = "021C668899"
    const val CUST_ID = "0001234567"

    val launchContext: DcaLaunchContext
        get() = DcaLaunchContext(
            custodyCd = CUSTODY_CD,
            custId = CUST_ID,
            subAccounts = listOf(
                DcaSubAccount(id = "0216688991", type = "Thường"),
                DcaSubAccount(id = "0216688996", type = "Ký quỹ"),
            ),
            defaultAcctNo = "0216688991",
            // "ROS" để demo lỗi FlutterError từ Host (mã bị hạn chế).
            symbols = listOf(
                "ACB", "BID", "CTG", "DGC", "FPT", "GAS", "HPG", "MBB", "MSN", "MWG",
                "PNJ", "REE", "ROS", "SAB", "SSI", "STB", "TCB", "VCB", "VHM", "VIC",
                "VJC", "VNM", "VPB", "VRE",
            ),
        )
}
