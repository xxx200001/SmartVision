import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 纯代码搭建界面：导航控制器 + 识别页（主页面）
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: RecognizeViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}
