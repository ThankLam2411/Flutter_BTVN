import Foundation

/// Phiên đăng nhập giả lập của Host App (thực tế lấy từ module Auth của app).
enum MockUserSession {
    static let custodyCd = "021C668899"
    static let custId = "0001234567"

    static var launchContext: DcaLaunchContext {
        DcaLaunchContext(
            custodyCd: custodyCd,
            custId: custId,
            subAccounts: [
                DcaSubAccount(id: "0216688991", type: "Thường"),
                DcaSubAccount(id: "0216688996", type: "Ký quỹ"),
            ],
            defaultAcctNo: "0216688991",
            // "ROS" để demo lỗi PigeonError từ Host (mã bị hạn chế).
            symbols: [
                "ACB", "BID", "CTG", "DGC", "FPT", "GAS", "HPG", "MBB", "MSN", "MWG",
                "PNJ", "REE", "ROS", "SAB", "SSI", "STB", "TCB", "VCB", "VHM", "VIC",
                "VJC", "VNM", "VPB", "VRE",
            ]
        )
    }
}
