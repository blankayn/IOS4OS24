import UIKit

final class LockScreenViewController: UIViewController, UIGestureRecognizerDelegate {
    let store: LegacyStore
    var unlock: (() -> Void)?
    private let scroll = UIScrollView()
    private let dateLabel = Palette.label("", size: 18, weight: .semibold)
    private let clockLabel = Palette.label("", size: 82, weight: .thin)
    private let caption = Palette.label("LOCK SCREEN PREVIEW", size: 11, weight: .semibold)
    private let notificationHeader = Palette.label("Sample notifications", size: 13, weight: .semibold)
    private let hint = Palette.label("Swipe up to enter\nA simulation inside iOS26 Legacy", size: 13)
    private var cards: [GlassPane] = []
    private var enterButton: UIButton!
    private var dismissButton: UIButton!

    init(store: LegacyStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "Lock preview" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "lock.screen"
        view.addSubview(scroll)
        for label in [dateLabel, clockLabel, caption, notificationHeader, hint] { scroll.addSubview(label) }
        for label in [dateLabel, clockLabel, caption, hint] { label.textAlignment = .center }
        let samples = [("MESSAGES · SAMPLE", "Alex", "See you by the waterfront at six."),
                       ("REMINDERS · SAMPLE", "A moment for yourself", "Take a short walk and enjoy the evening.")]
        for (source, name, body) in samples {
            let pane = GlassPane(radius: 23)
            let top = Palette.label(source, size: 10, weight: .semibold); top.tag = 1
            let title = Palette.label(name, size: 15, weight: .semibold); title.tag = 2
            let text = Palette.label(body, size: 13); text.tag = 3
            for label in [top, title, text] { pane.content.addSubview(label) }
            scroll.addSubview(pane); cards.append(pane)
        }
        enterButton = Palette.button("Enter Home", target: self, action: #selector(enter))
        enterButton.accessibilityIdentifier = "lock.enter"
        dismissButton = Palette.button("Clear samples", target: self, action: #selector(clearSamples))
        scroll.addSubview(enterButton); scroll.addSubview(dismissButton)
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(enter)); swipe.direction = .up
        swipe.delegate = self
        view.addGestureRecognizer(swipe)
        updateClock(); refreshGlass()
    }
    func refreshGlass() { for pane in cards { pane.configure(blur: false) } }
    func updateClock() {
        let date = DateFormatter(); date.dateFormat = "EEEE, MMMM d"
        let time = DateFormatter(); time.dateFormat = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: Locale.current)
        dateLabel.text = date.string(from: Date()); clockLabel.text = time.string(from: Date())
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); scroll.frame = view.bounds
        let width = view.bounds.width
        caption.frame = CGRect(x: 20, y: 10, width: width - 40, height: 20)
        dateLabel.frame = CGRect(x: 20, y: 43, width: width - 40, height: 28)
        clockLabel.frame = CGRect(x: 14, y: 68, width: width - 28, height: 99)
        notificationHeader.frame = CGRect(x: 27, y: 200, width: width - 54, height: 23)
        for (i, pane) in cards.enumerated() {
            pane.frame = CGRect(x: 20, y: 230 + CGFloat(i) * 98, width: width - 40, height: 88)
            pane.content.viewWithTag(1)?.frame = CGRect(x: 16, y: 10, width: pane.bounds.width - 32, height: 16)
            pane.content.viewWithTag(2)?.frame = CGRect(x: 16, y: 29, width: pane.bounds.width - 32, height: 19)
            pane.content.viewWithTag(3)?.frame = CGRect(x: 16, y: 50, width: pane.bounds.width - 32, height: 29)
        }
        dismissButton.frame = CGRect(x: (width - 136) / 2, y: 434, width: 136, height: 36)
        enterButton.frame = CGRect(x: (width - 180) / 2, y: 488, width: 180, height: 44)
        hint.frame = CGRect(x: 20, y: 544, width: width - 40, height: 42)
        scroll.contentSize = CGSize(width: width, height: 600)
    }
    @objc private func enter() { unlock?() }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { return true }
    @objc private func clearSamples() {
        for pane in cards { Motion.animate { pane.alpha = 0 } }
        notificationHeader.text = "No sample notifications"; dismissButton.isHidden = true
        UIAccessibility.post(notification: .announcement, argument: "Sample notifications cleared")
    }
}
