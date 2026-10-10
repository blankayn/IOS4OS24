import UIKit

final class ShellViewController: UIViewController, UIGestureRecognizerDelegate {
    let store = LegacyStore(defaults: ProcessInfo.processInfo.arguments.contains("--ui-testing") ? UserDefaults(suiteName: "iOS26Legacy.UITests")! : .standard)
    private let wallpaper = UIImageView()
    private let titleLabel = Palette.label("iOS26 Legacy", size: 13, weight: .semibold)
    private let toolbar = UIView()
    private let host = UIView()
    private let gestureZone = UIView()
    private let homeButton = UIButton(type: .system)
    private let dimmer = UIView()
    private lazy var home = HomeViewController(store: store)
    private var active: UIViewController?
    private var controlsButton: UIButton!
    private var lockButton: UIButton!
    private var switcherButton: UIButton!
    private var timer: Timer?
    private var lastPanMovement: TimeInterval = 0
    private var lastPanPosition = CGPoint.zero
    private var appBrightness: CGFloat = 0.85
    private let controlState = ControlState()
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink
        wallpaper.contentMode = .scaleAspectFill; wallpaper.clipsToBounds = true
        view.addSubview(wallpaper); view.addSubview(host); view.addSubview(toolbar); view.addSubview(gestureZone)
        toolbar.addSubview(titleLabel)
        controlsButton = Palette.button("Controls", target: self, action: #selector(showControls))
        lockButton = Palette.button("Lock", target: self, action: #selector(showLock))
        switcherButton = Palette.button("Apps", target: self, action: #selector(showSwitcher))
        for button in [controlsButton!, lockButton!, switcherButton!] { toolbar.addSubview(button) }
        controlsButton.accessibilityIdentifier = "shell.controls"
        lockButton.accessibilityIdentifier = "shell.lock"
        switcherButton.accessibilityIdentifier = "shell.switcher"
        homeButton.setTitle("Home", for: .normal); homeButton.setTitleColor(.white, for: .normal)
        homeButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        homeButton.addTarget(self, action: #selector(showHome), for: .touchUpInside)
        homeButton.accessibilityLabel = "Return to simulated Home Screen"
        homeButton.accessibilityIdentifier = "shell.home"
        gestureZone.addSubview(homeButton)
        let bar = UIView(); bar.tag = 99; bar.backgroundColor = .white; bar.layer.cornerRadius = 2
        gestureZone.addSubview(bar)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(homePan(_:)))
        pan.delegate = self; gestureZone.addGestureRecognizer(pan)
        let down = UISwipeGestureRecognizer(target: self, action: #selector(showControls)); down.direction = .down
        toolbar.addGestureRecognizer(down)
        home.openApp = { [weak self] in self?.open($0) }
        addChild(home); host.addSubview(home.view); home.didMove(toParent: self)
        dimmer.backgroundColor = .black; dimmer.isUserInteractionEnabled = false
        view.addSubview(dimmer); dimmer.alpha = (1 - appBrightness) * 0.65
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: LegacyStore.changed, object: store)
        NotificationCenter.default.addObserver(self, selector: #selector(startClock), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopClock), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(tick), name: UIApplication.significantTimeChangeNotification, object: nil)
        _ = DeviceInfo.shared
        startClock()
    }
    deinit { timer?.invalidate(); NotificationCenter.default.removeObserver(self) }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        let width = view.bounds.width
        wallpaper.frame = view.bounds
        wallpaper.image = Wallpaper.image(size: view.bounds.size, theme: store.preferences.wallpaper)
        toolbar.frame = CGRect(x: 0, y: safe.top + 2, width: width, height: 44)
        titleLabel.frame = CGRect(x: 18, y: 6, width: max(85, width - 241), height: 32)
        controlsButton.frame = CGRect(x: width - 215, y: 4, width: 85, height: 36)
        lockButton.frame = CGRect(x: width - 122, y: 4, width: 48, height: 36)
        switcherButton.frame = CGRect(x: width - 66, y: 4, width: 48, height: 36)
        let bottomHeight: CGFloat = 44 + safe.bottom
        gestureZone.frame = CGRect(x: 0, y: view.bounds.height - bottomHeight, width: width, height: bottomHeight)
        homeButton.frame = CGRect(x: (width - 120) / 2, y: 0, width: 120, height: 30)
        gestureZone.viewWithTag(99)?.frame = CGRect(x: (width - 104) / 2, y: 33, width: 104, height: 4)
        host.frame = CGRect(x: 0, y: toolbar.frame.maxY + 3, width: width, height: max(0, gestureZone.frame.minY - toolbar.frame.maxY - 3))
        home.view.frame = host.bounds; active?.view.frame = host.bounds
        dimmer.frame = view.bounds
    }

    private func display(_ controller: UIViewController?) {
        view.endEditing(true)
        active?.willMove(toParent: nil)
        active?.view.removeFromSuperview()
        active?.removeFromParent()
        active = controller
        home.view.isHidden = controller != nil
        if let controller = controller {
            addChild(controller); host.addSubview(controller.view)
            controller.view.frame = host.bounds; controller.didMove(toParent: self)
            controller.view.alpha = UIAccessibility.isReduceMotionEnabled ? 1 : 0
            controller.view.transform = UIAccessibility.isReduceMotionEnabled ? .identity : CGAffineTransform(translationX: 0, y: 18)
            Motion.animate { controller.view.alpha = 1; controller.view.transform = .identity }
            titleLabel.text = controller.title ?? "iOS26 Legacy"
        } else { titleLabel.text = "iOS26 Legacy"; home.updateWidget() }
        UIAccessibility.post(notification: .screenChanged, argument: controller?.view ?? home.view)
    }

    func open(_ app: LegacyApp) {
        Motion.tap(store); store.visit(app)
        if app.id == "settings" { display(CustomizeViewController(store: store)); return }
        display(AppScreenViewController(app: app, store: store))
    }
    @objc private func showHome() { Motion.tap(store); display(nil) }
    @objc private func showControls() {
        if active is ControlCenterViewController { resume(); return }
        controlOrigin = (active as? AppScreenViewController)?.app
        if active is CustomizeViewController { controlOrigin = LegacyApp.find("settings") }
        Motion.tap(store)
        let controller = ControlCenterViewController(store: store, state: controlState)
        controller.brightness = appBrightness
        controller.brightnessChanged = { [weak self] value in
            self?.appBrightness = value; self?.dimmer.alpha = (1 - value) * 0.65
        }
        controller.done = { [weak self] in self?.resume() }
        display(controller)
    }
    private func resume() {
        // Controls return to the most recent internal app only if it was the origin.
        if let app = controlOrigin { open(app) } else { display(nil) }
        controlOrigin = nil
    }
    private var controlOrigin: LegacyApp?

    @objc private func showLock() {
        Motion.tap(store)
        let lock = LockScreenViewController(store: store)
        lock.unlock = { [weak self] in self?.showHome() }
        display(lock)
    }
    @objc private func showSwitcher() {
        Motion.tap(store)
        let switcher = SwitcherViewController(store: store)
        switcher.openApp = { [weak self] in self?.open($0) }
        display(switcher)
    }
    @objc private func homePan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            lastPanMovement = CACurrentMediaTime(); lastPanPosition = .zero
        case .changed:
            let position = pan.translation(in: gestureZone)
            if abs(position.y - lastPanPosition.y) > 3 {
                lastPanMovement = CACurrentMediaTime(); lastPanPosition = position
            }
        case .ended:
            let delta = pan.translation(in: gestureZone)
            guard delta.y < -28 else { return }
            let held = delta.y < -45 && CACurrentMediaTime() - lastPanMovement > 0.35
            if held { showSwitcher() } else { showHome() }
        default: break
        }
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: gestureZone)
        return abs(velocity.y) > abs(velocity.x)
    }
    @objc private func preferencesChanged() {
        home.rebuild(); view.setNeedsLayout()
        if let lock = active as? LockScreenViewController { lock.refreshGlass() }
        if let controls = active as? ControlCenterViewController { controls.refreshGlass() }
    }
    @objc private func startClock() {
        stopClock()
        timer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer?.tolerance = 2
        tick()
    }
    @objc private func stopClock() { timer?.invalidate(); timer = nil }
    @objc private func tick() {
        if active == nil { home.updateWidget() }
        (active as? LockScreenViewController)?.updateClock()
        (active as? AppScreenViewController)?.refreshTime()
    }
    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning(); Wallpaper.clearCache() }
}
