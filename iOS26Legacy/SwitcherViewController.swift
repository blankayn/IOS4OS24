import UIKit

final class SwitcherViewController: UIViewController, UIScrollViewDelegate {
    let store: LegacyStore
    var openApp: ((LegacyApp) -> Void)?
    private let scroll = UIScrollView()
    private let heading = Palette.label("Recent apps", size: 30, weight: .bold)
    private let hint = Palette.label("Swipe sideways to browse. Swipe a card up to close.\nThese cards represent screens inside this app.", size: 13)
    private let empty = Palette.label("Your next moment starts here.\nOpen an app from Home to see it here.", size: 20, weight: .light)
    private var cards: [GlassPane] = []
    private var ids: [String] = []

    init(store: LegacyStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "Recent apps" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "switcher.screen"
        view.backgroundColor = Palette.ink.withAlphaComponent(0.4)
        view.addSubview(heading); view.addSubview(hint); view.addSubview(scroll); view.addSubview(empty)
        hint.textAlignment = .center; empty.textAlignment = .center
        scroll.showsHorizontalScrollIndicator = false; scroll.decelerationRate = .fast; scroll.delegate = self
        rebuild()
    }
    private func rebuild() {
        for card in cards { card.removeFromSuperview() }; cards.removeAll()
        ids = store.recents
        empty.isHidden = !ids.isEmpty
        for (index, id) in ids.enumerated() {
            guard let app = LegacyApp.find(id) else { continue }
            let pane = GlassPane(radius: 32); pane.configure(blur: false); pane.tag = index
            let image = UIImageView(image: IconArt.image(app: app, clear: store.preferences.clearIcons)); image.tag = 1
            let name = Palette.label(app.title, size: 25, weight: .bold); name.tag = 2
            let detail = Palette.label(preview(app), size: 20, weight: .light); detail.tag = 3
            let open = Palette.button("Open", target: self, action: #selector(selectCard(_:))); open.tag = index
            open.accessibilityLabel = "Open \(app.title)"; open.accessibilityIdentifier = "recent.\(id)"
            let close = Palette.button("Close card", target: self, action: #selector(closeCard(_:))); close.tag = index
            close.accessibilityLabel = "Close \(app.title) card"
            // Separate identifiers for layout; button tags encode the recent index.
            open.accessibilityIdentifier = "recent.\(id)"; close.accessibilityIdentifier = "closeRecent.\(id)"
            for item in [image, name, detail, open, close] as [UIView] { pane.content.addSubview(item) }
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(dismissCard(_:))); swipe.direction = .up
            pane.addGestureRecognizer(swipe)
            scroll.addSubview(pane); cards.append(pane)
        }
        view.setNeedsLayout()
    }
    private func preview(_ app: LegacyApp) -> String {
        switch app.id {
        case "notes": return String(store.note.prefix(180))
        case "settings": return "Your Home.\nYour colors.\nYour pace."
        case "health": return DeviceInfo.shared.summary
        case "weather": return "26°\nMostly sunny\nSample weather"
        default: return "\(app.title)\n\nTap Open to return to this internal screen."
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        heading.frame = CGRect(x: 24, y: 15, width: width - 48, height: 42)
        let cardHeight = max(280, view.bounds.height - 144)
        scroll.frame = CGRect(x: 0, y: 75, width: width, height: cardHeight)
        let stride = width * 0.78
        for (index, pane) in cards.enumerated() {
            pane.frame = CGRect(x: 28 + CGFloat(index) * stride, y: 0, width: stride - 14, height: cardHeight - 5)
            let items = pane.content.subviews
            items[0].frame = CGRect(x: 22, y: 24, width: 54, height: 54)
            items[1].frame = CGRect(x: 22, y: 94, width: pane.bounds.width - 44, height: 40)
            items[2].frame = CGRect(x: 22, y: 145, width: pane.bounds.width - 44, height: max(40, pane.bounds.height - 274))
            items[3].frame = CGRect(x: 20, y: pane.bounds.height - 110, width: pane.bounds.width - 40, height: 44)
            items[4].frame = CGRect(x: 20, y: pane.bounds.height - 56, width: pane.bounds.width - 40, height: 36)
        }
        scroll.contentSize = CGSize(width: max(width, 56 + CGFloat(cards.count) * stride - 14), height: cardHeight)
        hint.frame = CGRect(x: 20, y: scroll.frame.maxY + 12, width: width - 40, height: 45)
        empty.frame = CGRect(x: 36, y: 150, width: width - 72, height: 140)
    }
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let stride = view.bounds.width * 0.78
        targetContentOffset.pointee.x = max(0, min(scroll.contentSize.width - scroll.bounds.width, round(targetContentOffset.pointee.x / stride) * stride))
    }
    @objc private func selectCard(_ button: UIButton) { guard ids.indices.contains(button.tag), let app = LegacyApp.find(ids[button.tag]) else { return }; openApp?(app) }
    @objc private func closeCard(_ button: UIButton) { dismissIndex(button.tag) }
    @objc private func dismissCard(_ gesture: UISwipeGestureRecognizer) { if let index = gesture.view?.tag { dismissIndex(index) } }
    private func dismissIndex(_ index: Int) {
        guard ids.indices.contains(index), cards.indices.contains(index) else { return }
        let pane = cards[index]
        // Disable interaction while the recent list is being mutated.
        scroll.isUserInteractionEnabled = false
        Motion.tap(store)
        Motion.animate { pane.transform = CGAffineTransform(translationX: 0, y: -self.view.bounds.height); pane.alpha = 0 } completion: { _ in
            self.store.closeRecent(self.ids[index]); self.rebuild(); self.scroll.isUserInteractionEnabled = true
            UIAccessibility.post(notification: .layoutChanged, argument: self.heading)
        }
    }
}
