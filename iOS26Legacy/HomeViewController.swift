import UIKit

final class HomeViewController: UIViewController, UIScrollViewDelegate {
    let store: LegacyStore
    var openApp: ((LegacyApp) -> Void)?
    private let scroll = UIScrollView()
    private let dots = UIPageControl()
    private let dock = GlassPane(radius: 32)
    private var pageViews: [UIView] = []
    private var widgets: [(GlassPane, UILabel, UILabel)] = []
    private var iconRows: [[AppIconButton]] = []
    private var dockIcons: [AppIconButton] = []
    private(set) var pageIndex = 0

    init(store: LegacyStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "home.screen"
        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = self
        scroll.alwaysBounceVertical = false
        scroll.delaysContentTouches = false
        view.addSubview(scroll); view.addSubview(dots); view.addSubview(dock)
        dots.addTarget(self, action: #selector(selectPage), for: .valueChanged)
        dots.accessibilityLabel = "Home Screen pages"
        dots.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        dots.currentPageIndicatorTintColor = .white
        rebuild()
    }

    func rebuild() {
        guard isViewLoaded else { return }
        for page in pageViews { page.removeFromSuperview() }
        for icon in dockIcons { icon.removeFromSuperview() }
        pageViews.removeAll(); widgets.removeAll(); iconRows.removeAll(); dockIcons.removeAll()
        let prefs = store.preferences
        for ids in prefs.pages {
            let page = UIView(); scroll.addSubview(page); pageViews.append(page)
            let widget = GlassPane(radius: 26)
            // Widgets/icons remain static glass; blur is reserved for one dock or overlay.
            widget.configure(blur: false)
            let eyebrow = Palette.label("", size: 12, weight: .semibold)
            let detail = Palette.label("", size: 24, weight: .light)
            widget.content.addSubview(eyebrow); widget.content.addSubview(detail)
            page.addSubview(widget); widget.isHidden = prefs.widget == 3
            widgets.append((widget, eyebrow, detail))
            let icons = ids.compactMap { LegacyApp.find($0) }.map { makeIcon($0) }
            for icon in icons { page.addSubview(icon) }
            iconRows.append(icons)
        }
        for app in prefs.dock.compactMap({ LegacyApp.find($0) }) {
            let icon = makeIcon(app, showLabel: false)
            dock.content.addSubview(icon); dockIcons.append(icon)
        }
        dock.configure(blur: prefs.blur)
        dots.numberOfPages = pageViews.count
        pageIndex = min(pageIndex, pageViews.count - 1)
        dots.currentPage = pageIndex
        updateWidget()
        view.setNeedsLayout(); view.layoutIfNeeded()
        scroll.contentOffset = CGPoint(x: CGFloat(pageIndex) * scroll.bounds.width, y: 0)
    }

    private func makeIcon(_ app: LegacyApp, showLabel: Bool = true) -> AppIconButton {
        let icon = AppIconButton(app: app, clear: store.preferences.clearIcons, showLabel: showLabel)
        icon.tapped = { [weak self] app in self?.openApp?(app) }
        return icon
    }

    func updateWidget() {
        for icon in iconRows.flatMap({ $0 }) + dockIcons where icon.app.id == "calendar" {
            icon.refresh(clear: store.preferences.clearIcons)
        }
        let date = DateFormatter(); date.dateFormat = "EEEE, MMMM d"
        let time = DateFormatter(); time.timeStyle = .short
        for (_, eyebrow, detail) in widgets {
            switch store.preferences.widget {
            case 1: eyebrow.text = "THIS DEVICE"; detail.text = DeviceInfo.shared.battery + " · " + DeviceInfo.shared.connection
                detail.font = .systemFont(ofSize: 17, weight: .medium)
            case 2: eyebrow.text = "WEATHER · DEMO"; detail.text = "26°  Mostly sunny"
                detail.font = .systemFont(ofSize: 26, weight: .light)
            default: eyebrow.text = date.string(from: Date()).uppercased(); detail.text = time.string(from: Date())
                detail.font = .systemFont(ofSize: 30, weight: .light)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        let dockHeight: CGFloat = 88
        let dockY = view.bounds.height - dockHeight - 2
        dock.frame = CGRect(x: 14, y: dockY, width: width - 28, height: dockHeight)
        dots.frame = CGRect(x: 0, y: dockY - 28, width: width, height: 24)
        scroll.frame = CGRect(x: 0, y: 0, width: width, height: max(0, dockY - 30))
        scroll.contentSize = CGSize(width: width * CGFloat(pageViews.count), height: scroll.bounds.height)
        for (index, page) in pageViews.enumerated() {
            page.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: scroll.bounds.height)
            let (widget, eyebrow, detail) = widgets[index]
            let widgetHeight: CGFloat = store.preferences.widget == 3 ? 0 : 98
            widget.frame = CGRect(x: 22, y: 8, width: width - 44, height: 88)
            eyebrow.frame = CGRect(x: 18, y: 12, width: widget.bounds.width - 36, height: 18)
            detail.frame = CGRect(x: 18, y: 34, width: widget.bounds.width - 36, height: 42)
            let columns = store.preferences.columns
            let icons = iconRows[index]
            let rowCount = max(1, Int(ceil(Double(icons.count) / Double(columns))))
            let available = max(72, scroll.bounds.height - widgetHeight - 8)
            let rowHeight = min(102, available / CGFloat(rowCount))
            let cellWidth = (width - 26) / CGFloat(columns)
            for (i, icon) in icons.enumerated() {
                icon.frame = CGRect(x: 13 + CGFloat(i % columns) * cellWidth,
                                    y: widgetHeight + 8 + CGFloat(i / columns) * rowHeight,
                                    width: cellWidth, height: rowHeight - 2)
            }
        }
        let cellWidth = (dock.bounds.width - 16) / 4
        for (i, icon) in dockIcons.enumerated() {
            icon.frame = CGRect(x: 8 + CGFloat(i) * cellWidth, y: 12, width: cellWidth, height: 64)
        }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { syncPage() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { syncPage() }
    private func syncPage() {
        guard scroll.bounds.width > 0 else { return }
        pageIndex = min(pageViews.count - 1, max(0, Int(round(scroll.contentOffset.x / scroll.bounds.width))))
        dots.currentPage = pageIndex
    }
    @objc private func selectPage() {
        scroll.setContentOffset(CGPoint(x: CGFloat(dots.currentPage) * scroll.bounds.width, y: 0), animated: !UIAccessibility.isReduceMotionEnabled)
        pageIndex = dots.currentPage
    }
}
