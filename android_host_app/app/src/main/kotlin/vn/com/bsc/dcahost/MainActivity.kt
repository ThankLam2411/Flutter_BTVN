package vn.com.bsc.dcahost

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import vn.com.bsc.dcahost.bridge.DcaFlowResult
import vn.com.bsc.dcahost.bridge.DcaFlowStatus
import vn.com.bsc.dcahost.bridge.DcaPlanRequest
import vn.com.bsc.dcahost.flutter.DcaModule
import vn.com.bsc.dcahost.flutter.detailText
import vn.com.bsc.dcahost.flutter.oddLotText
import vn.com.bsc.dcahost.flutter.summary
import vn.com.bsc.dcahost.flutter.createDateText

/** Màn hình native của Host App: mở Flutter Module & hiển thị kế hoạch nhận được. */
class MainActivity : AppCompatActivity() {
    private data class ReceivedPlan(val plan: DcaPlanRequest, val quoteId: String)

    private val receivedPlans = mutableListOf<ReceivedPlan>()

    private lateinit var symbolInput: EditText
    private lateinit var statusText: TextView
    private lateinit var plansHeader: TextView
    private lateinit var plansContainer: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val root = findViewById<android.view.View>(R.id.root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.updatePadding(top = bars.top, bottom = bars.bottom) // edge-to-edge (targetSdk 36)
            insets
        }

        symbolInput = findViewById(R.id.symbolInput)
        statusText = findViewById(R.id.statusText)
        plansHeader = findViewById(R.id.plansHeader)
        plansContainer = findViewById(R.id.plansContainer)
        findViewById<TextView>(R.id.accountText).text =
            getString(R.string.account_info, MockUserSession.CUSTODY_CD, MockUserSession.CUST_ID)
        findViewById<Button>(R.id.openButton).setOnClickListener { openDcaModule() }

        // Nhận dữ liệu ngay khi Flutter submit (HostApi.submitPlan).
        DcaModule.onPlanReceived = { plan, result ->
            statusText.text = "submitPlan ← Flutter: ${plan.symbol} (${result.quoteId})"
        }
        renderPlans()
    }

    override fun onDestroy() {
        DcaModule.onPlanReceived = null // không giữ tham chiếu Activity trong singleton
        super.onDestroy()
    }

    private fun openDcaModule() {
        statusText.text = "Đang mở Flutter Module…"
        DcaModule.open(
            activity = this,
            context = MockUserSession.launchContext,
            presetSymbol = symbolInput.text?.toString(),
        ) { result -> handle(result) }
    }

    private fun handle(result: DcaFlowResult) {
        when (result.status) {
            DcaFlowStatus.CANCELLED -> statusText.text = "finish ← Flutter: người dùng huỷ"
            DcaFlowStatus.SUBMITTED -> {
                val plan = result.plan ?: return
                val quoteId = result.quoteId ?: "-"
                receivedPlans.add(0, ReceivedPlan(plan, quoteId))
                renderPlans()
                statusText.text = "finish ← Flutter: đã lập kế hoạch $quoteId"
                AlertDialog.Builder(this)
                    .setTitle("Đã nhận kế hoạch từ Flutter")
                    .setMessage(plan.detailText)
                    .setPositiveButton("OK", null)
                    .show()
            }
        }
    }

    private fun renderPlans() {
        plansHeader.text = "Kế hoạch nhận từ Flutter Module (${receivedPlans.size})"
        plansContainer.removeAllViews()
        if (receivedPlans.isEmpty()) {
            plansContainer.addView(planRow("Chưa có kế hoạch nào được lập", null))
            return
        }
        receivedPlans.forEach { item ->
            plansContainer.addView(
                planRow(
                    item.plan.summary,
                    "${item.quoteId} · TK ${item.plan.acctNo} · ${item.plan.oddLotText} · ${item.plan.createDateText}",
                ),
            )
        }
    }

    private fun planRow(title: String, subtitle: String?): android.view.View {
        val row = layoutInflater.inflate(R.layout.item_plan, plansContainer, false)
        row.findViewById<TextView>(R.id.planTitle).text = title
        row.findViewById<TextView>(R.id.planSubtitle).apply {
            text = subtitle.orEmpty()
            visibility = if (subtitle == null) android.view.View.GONE else android.view.View.VISIBLE
        }
        return row
    }
}
