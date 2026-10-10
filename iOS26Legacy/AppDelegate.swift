import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            UserDefaults(suiteName: "iOS26Legacy.UITests")?.removePersistentDomain(forName: "iOS26Legacy.UITests")
        }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = ShellViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
