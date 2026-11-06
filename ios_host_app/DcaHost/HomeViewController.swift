import UIKit

/// Màn hình native của Host App: mở Flutter Module & hiển thị kế hoạch nhận được.
final class HomeViewController: UIViewController {
    private struct ReceivedPlan {
        let plan: DcaPlanRequest
        let quoteId: String
    }

    private var receivedPlans: [ReceivedPlan] = []

    private let symbolField = UITextField()
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BSC Host App"
        view.backgroundColor = .systemGroupedBackground
        setupLayout()

        // Nhận dữ liệu ngay khi Flutter submit (HostApi.submitPlan).
        DcaModule.shared.onPlanReceived = { [weak self] plan, result in
            self?.statusLabel.text = "submitPlan ← Flutter: \(plan.symbol) (\(result.quoteId))"
        }
    }

    // MARK: - Actions

    @objc private func openDcaModule() {
        view.endEditing(true)
        statusLabel.text = "Đang mở Flutter Module…"
        DcaModule.shared.open(
            from: self,
            context: MockUserSession.launchContext,
            presetSymbol: symbolField.text
        ) { [weak self] result in
            self?.handle(result)
        }
    }

    private func handle(_ result: DcaFlowResult) {
        switch result.status {
        case .cancelled:
            statusLabel.text = "finish ← Flutter: người dùng huỷ"
        case .submitted:
            guard let plan = result.plan else { return }
            let quoteId = result.quoteId ?? "-"
            receivedPlans.insert(ReceivedPlan(plan: plan, quoteId: quoteId), at: 0)
            tableView.reloadData()
            statusLabel.text = "finish ← Flutter: đã lập kế hoạch \(quoteId)"

            let alert = UIAlertController(
                title: "Đã nhận kế hoạch từ Flutter",
                message: plan.detailText,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        let accountLabel = UILabel()
        accountLabel.numberOfLines = 0
        accountLabel.font = .preferredFont(forTextStyle: .subheadline)
        accountLabel.text = "Khách hàng: \(MockUserSession.custodyCd) · Mã KH: \(MockUserSession.custId)"

        symbolField.placeholder = "Mã CK gợi ý (tuỳ chọn), vd: FPT"
        symbolField.borderStyle = .roundedRect
        symbolField.autocapitalizationType = .allCharacters
        symbolField.autocorrectionType = .no
        symbolField.clearButtonMode = .whileEditing

        var config = UIButton.Configuration.filled()
        config.title = "Đầu tư định kỳ (Flutter)"
        config.image = UIImage(systemName: "calendar.badge.plus")
        config.imagePadding = 8
        let openButton = UIButton(configuration: config)
        openButton.addTarget(self, action: #selector(openDcaModule), for: .touchUpInside)

        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Engine đã warm-up khi mở app."

        let header = UIStackView(arrangedSubviews: [accountLabel, symbolField, openButton, statusLabel])
        header.axis = .vertical
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(tableView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            openButton.heightAnchor.constraint(equalToConstant: 48),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: - UITableViewDataSource

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Kế hoạch nhận từ Flutter Module (\(receivedPlans.count))"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(receivedPlans.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        guard !receivedPlans.isEmpty else {
            cell.textLabel?.text = "Chưa có kế hoạch nào được lập"
            cell.textLabel?.textColor = .secondaryLabel
            return cell
        }
        let item = receivedPlans[indexPath.row]
        cell.textLabel?.text = item.plan.summary
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.text =
            "\(item.quoteId) · TK \(item.plan.acctNo) · \(item.plan.oddLotText) · \(item.plan.createDateText)"
        return cell
    }
}
