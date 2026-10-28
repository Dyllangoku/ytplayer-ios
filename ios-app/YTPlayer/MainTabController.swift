import UIKit

final class MainTabController: UITabBarController, UITabBarControllerDelegate {
    private let youtube = WebViewController(title: "유튜브",
                                            url: URL(string: "https://m.youtube.com")!,
                                            symbol: "play.rectangle.fill")
    private let music = WebViewController(title: "뮤직",
                                          url: URL(string: "https://music.youtube.com")!,
                                          symbol: "music.note")

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        tabBar.tintColor = .systemRed
        viewControllers = [youtube, music, UINavigationController(rootViewController: SettingsViewController())]
        ScriptManager.shared.checkForUpdate()   // 앱 켤 때 자동 확인
    }

    // 유튜브 ↔ 뮤직을 바꾸면 다른 쪽 재생은 멈춘다 (업데이트 탭으로 갈 때는 계속 재생)
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard viewController is WebViewController else { return }
        for case let page as WebViewController in viewControllers ?? [] where page !== viewController {
            page.pauseMedia()
        }
    }
}
