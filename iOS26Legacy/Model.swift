import UIKit
import Network
import Darwin

struct LegacyApp: Equatable {
    let id: String
    let title: String
    let glyph: String
    let hue: CGFloat

    static let catalog: [LegacyApp] = [
        LegacyApp(id: "messages", title: "Messages", glyph: "chat", hue: 0.36),
        LegacyApp(id: "calendar", title: "Calendar", glyph: "calendar", hue: 0.02),
        LegacyApp(id: "photos", title: "Gallery", glyph: "flower", hue: 0.82),
        LegacyApp(id: "camera", title: "Camera", glyph: "camera", hue: 0.58),
        LegacyApp(id: "weather", title: "Weather", glyph: "sun", hue: 0.56),
        LegacyApp(id: "clock", title: "Clock", glyph: "clock", hue: 0.62),
        LegacyApp(id: "maps", title: "Maps", glyph: "map", hue: 0.38),
        LegacyApp(id: "notes", title: "Notes", glyph: "notes", hue: 0.13),
        LegacyApp(id: "calculator", title: "Calculator", glyph: "calculator", hue: 0.08),
        LegacyApp(id: "settings", title: "Customize", glyph: "gear", hue: 0.59),
        LegacyApp(id: "files", title: "Files", glyph: "folder", hue: 0.57),
        LegacyApp(id: "health", title: "Device", glyph: "heart", hue: 0.96),
        LegacyApp(id: "music", title: "Music", glyph: "music", hue: 0.96),
        LegacyApp(id: "links", title: "Open Apps", glyph: "link", hue: 0.66),
        LegacyApp(id: "safari", title: "Browser", glyph: "compass", hue: 0.56),
        LegacyApp(id: "phone", title: "Phone", glyph: "phone", hue: 0.36)
    ]

    static func find(_ id: String) -> LegacyApp? { return catalog.first { $0.id == id } }
}

struct Preferences: Codable {
    var wallpaper = 0
    var columns = 4
    var widget = 0 // 0: date, 1: device, 2: demo weather, 3: none
    var blur = false
    var clearIcons = true
    var haptics = true
    var pages: [[String]] = [
        ["messages", "calendar", "photos", "camera", "weather", "clock", "maps", "notes"],
        ["calculator", "settings", "files", "health", "music", "links"]
    ]
    var dock = ["phone", "safari", "messages", "music"]

    mutating func sanitize() {
        wallpaper = min(3, max(0, wallpaper))
        columns = columns == 3 ? 3 : 4
        widget = min(3, max(0, widget))
        pages = Array(pages.prefix(5)).map { page in
            var seen = Set<String>()
            return Array(page.filter { LegacyApp.find($0) != nil && seen.insert($0).inserted }.prefix(12))
        }
        if pages.isEmpty { pages = Preferences().pages }
        dock = Array(dock.filter { LegacyApp.find($0) != nil }.prefix(4))
        if dock.count != 4 { dock = Preferences().dock }
    }
}

final class LegacyStore {
    static let changed = Notification.Name("LegacyStoreChanged")
    private let defaults: UserDefaults
    private(set) var preferences: Preferences
    private(set) var recents: [String] = []
    var note: String {
        get { return defaults.string(forKey: "legacy.note") ?? "A little space for your thoughts.\n\nThis note stays on this device." }
        set { defaults.set(newValue, forKey: "legacy.note") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var prefs = defaults.data(forKey: "legacy.preferences").flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        prefs.sanitize()
        preferences = prefs
    }

    func update(_ edit: (inout Preferences) -> Void) {
        edit(&preferences)
        preferences.sanitize()
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "legacy.preferences") }
        NotificationCenter.default.post(name: LegacyStore.changed, object: self)
    }

    func visit(_ app: LegacyApp) {
        recents.removeAll { $0 == app.id }
        recents.insert(app.id, at: 0)
        recents = Array(recents.prefix(6))
    }
    func closeRecent(_ id: String) { recents.removeAll { $0 == id } }
}

final class DeviceInfo {
    static let shared = DeviceInfo()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "legacy.network")
    private(set) var connection = "Checking network…"

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        monitor.pathUpdateHandler = { [weak self] path in
            let value: String
            if path.status != .satisfied { value = "No network route" }
            else if path.usesInterfaceType(.wifi) { value = "Wi-Fi route available" }
            else if path.usesInterfaceType(.cellular) { value = "Cellular route available" }
            else { value = "Network route available" }
            DispatchQueue.main.async { self?.connection = value }
        }
        monitor.start(queue: queue)
    }

    var battery: String {
        let level = UIDevice.current.batteryLevel
        return level < 0 ? "Battery unavailable" : "Battery \(Int(level * 100))%"
    }
    var summary: String { return "\(battery)\n\(connection)\niOS \(UIDevice.current.systemVersion)" }
}

enum Motion {
    static func animate(_ changes: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        if UIAccessibility.isReduceMotionEnabled {
            changes(); completion?(true)
        } else {
            UIView.animate(withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.86,
                           initialSpringVelocity: 0.3, options: [.beginFromCurrentState, .allowUserInteraction],
                           animations: changes, completion: completion)
        }
    }

    static func tap(_ store: LegacyStore) {
        guard store.preferences.haptics, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        // iPhone 6 has no Taptic Engine. iPhone 6s and later support UIKit feedback.
        var system = utsname()
        uname(&system)
        let machine = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        guard machine.hasPrefix("iPhone"), !machine.hasPrefix("iPhone7,") else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

enum PermittedLink: Int, CaseIterable {
    case web, mail, maps, spotify, messages
    var title: String {
        switch self {
        case .web: return "Open Apple in browser"
        case .mail: return "Compose email"
        case .maps: return "Open Apple Maps"
        case .spotify: return "Open Spotify (if installed)"
        case .messages: return "Compose a message"
        }
    }
    var url: URL {
        let value: String
        switch self {
        case .web: value = "https://www.apple.com/"
        case .mail: value = "mailto:"
        case .maps: value = "https://maps.apple.com/?q=Manila"
        case .spotify: value = "spotify://"
        case .messages: value = "sms:"
        }
        return URL(string: value)!
    }
    func open(from controller: UIViewController) {
        guard UIApplication.shared.canOpenURL(url) else {
            controller.message("Unavailable", "No installed application can handle this permitted link.")
            return
        }
        UIApplication.shared.open(url, options: [:]) { [weak controller] success in
            if !success { controller?.message("Couldn’t open app", "The application could not open this link.") }
        }
    }
}

extension UIViewController {
    func message(_ title: String, _ text: String) {
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
