import UIKit

/// '업데이트' 탭: 차단 기능 버전 확인 + 지금 업데이트
final class SettingsViewController: UIViewController {
    private let versionLabel = UILabel()
    private let statusLabel = UILabel()
    private let button = UIButton(type: .system)

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "업데이트"
        tabBarItem = UITabBarItem(title: "업데이트",
                                  image: UIImage(systemName: "arrow.triangle.2.circlepath"), tag: 2)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        versionLabel.font = .preferredFont(forTextStyle: .title2)
        versionLabel.textAlignment = .center

        var config = UIButton.Configuration.filled()
        config.title = "지금 업데이트"
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .large
        button.configuration = config
        button.addTarget(self, action: #selector(updateTapped), for: .touchUpInside)

        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel

        let info = UILabel()
        info.numberOfLines = 0
        info.textAlignment = .center
        info.font = .preferredFont(forTextStyle: .footnote)
        info.textColor = .secondaryLabel
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        info.text = """
        앱을 켜거나 다시 열 때마다 새 차단 기능을 자동으로 확인해요.
        광고가 다시 나오면 Claude에게 "광고 뚫렸어"라고 말한 뒤 여기서 업데이트를 누르세요.

        앱 버전 \(appVersion)
        """

        let stack = UIStackView(arrangedSubviews: [versionLabel, button, statusLabel, info])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(refreshVersion),
                                               name: .ytScriptUpdated, object: nil)
        refreshVersion()
    }

    @objc private func refreshVersion() {
        versionLabel.text = "차단 기능 v\(ScriptManager.shared.version)"
    }

    @objc private func updateTapped() {
        button.isEnabled = false
        statusLabel.text = "확인 중…"
        ScriptManager.shared.checkForUpdate { [weak self] result in
            guard let self else { return }
            self.button.isEnabled = true
            switch result {
            case .updated(let v): self.statusLabel.text = "v\(v)로 업데이트했어요. 영상 화면을 새로 불러옵니다."
            case .latest(let v): self.statusLabel.text = "이미 최신이에요 (v\(v))."
            case .failed(let msg): self.statusLabel.text = "업데이트 실패: \(msg)"
            }
            self.refreshVersion()
        }
    }
}
