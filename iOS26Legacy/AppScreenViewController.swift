import UIKit

final class ActionButton: UIButton {
    var action: (() -> Void)?
    init(_ title: String, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.action = action
        setTitle(title, for: .normal); setTitleColor(.white, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel?.numberOfLines = 2; titleLabel?.textAlignment = .center
        backgroundColor = UIColor.white.withAlphaComponent(0.12); layer.cornerRadius = 19
        addTarget(self, action: #selector(run), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func run() { action?() }
}

final class AppScreenViewController: UIViewController, UITextViewDelegate {
    let app: LegacyApp
    private let store: LegacyStore
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let heading: UILabel
    private let caption = Palette.label("", size: 12, weight: .semibold)
    private let note = UITextView()
    private var clock: UILabel?
    private var calculator = CalculatorEngine()
    private var calculatorDisplay: UILabel?
    private var numberField: UITextField?
    private var demoPlaying = false

    init(app: LegacyApp, store: LegacyStore) {
        self.app = app; self.store = store
        heading = Palette.label(app.title, size: 34, weight: .bold)
        super.init(nibName: nil, bundle: nil); title = app.title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "screen.\(app.id)"
        view.backgroundColor = Palette.ink.withAlphaComponent(0.75)
        view.addSubview(scroll)
        scroll.addSubview(stack)
        stack.axis = .vertical; stack.spacing = 16
        stack.addArrangedSubview(heading); stack.addArrangedSubview(caption)
        heading.heightAnchor.constraint(equalToConstant: 44).isActive = true
        caption.heightAnchor.constraint(equalToConstant: 22).isActive = true
        buildContent()
        let hint = Palette.label("Swipe up from the bottom Home area to return.", size: 12)
        hint.textColor = UIColor.white.withAlphaComponent(0.65); stack.addArrangedSubview(hint)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboard(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scroll.frame = view.bounds
        stack.frame = CGRect(x: 22, y: 17, width: view.bounds.width - 44, height: 0)
        let height = stack.systemLayoutSizeFitting(CGSize(width: stack.bounds.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        stack.frame.size.height = height
        scroll.contentSize = CGSize(width: view.bounds.width, height: height + 40)
    }
    private func body(_ text: String, size: CGFloat = 18) {
        let label = Palette.label(text, size: size)
        label.adjustsFontSizeToFitWidth = false
        stack.addArrangedSubview(label)
    }
    private func button(_ title: String, _ action: @escaping () -> Void) {
        let button = ActionButton(title, action: action)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stack.addArrangedSubview(button)
    }
    private func permitted(_ link: PermittedLink) {
        button(link.title) { [weak self] in guard let self = self else { return }; link.open(from: self) }
    }
    private func card(_ title: String, _ detail: String) {
        let box = UIView(); box.backgroundColor = UIColor.white.withAlphaComponent(0.08); box.layer.cornerRadius = 22
        let label = Palette.label(title + "\n" + detail, size: 17, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16), label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16), label.topAnchor.constraint(equalTo: box.topAnchor, constant: 16), label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16)])
        stack.addArrangedSubview(box)
    }
    private func buildContent() {
        switch app.id {
        case "notes":
            caption.text = "ON THIS DEVICE · AUTOSAVED"
            note.backgroundColor = UIColor.white.withAlphaComponent(0.09); note.textColor = .white
            note.font = .systemFont(ofSize: 19); note.layer.cornerRadius = 23
            note.textContainerInset = UIEdgeInsets(top: 18, left: 12, bottom: 18, right: 12)
            note.text = store.note; note.delegate = self
            note.accessibilityIdentifier = "notes.editor"
            note.heightAnchor.constraint(equalToConstant: 330).isActive = true
            let accessory = UIToolbar(); accessory.sizeToFit(); accessory.barStyle = .black
            accessory.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endEditing))]
            note.inputAccessoryView = accessory; stack.addArrangedSubview(note)
        case "calculator": buildCalculator()
        case "clock":
            caption.text = "LOCAL DEVICE TIME"
            let label = Palette.label("", size: 66, weight: .thin); clock = label; stack.addArrangedSubview(label)
            refreshTime()
            body("A quiet moment, beautifully displayed.")
        case "calendar":
            caption.text = "CURRENT MONTH · NO CALENDAR ACCESS"
            buildCalendar()
        case "photos":
            caption.text = "BUILT-IN WALLPAPER GALLERY"
            for (index, name) in Wallpaper.names.enumerated() {
                let image = UIImageView(image: Wallpaper.image(size: CGSize(width: 320, height: 160), theme: index))
                image.contentMode = .scaleAspectFill; image.clipsToBounds = true; image.layer.cornerRadius = 23
                image.heightAnchor.constraint(equalToConstant: 160).isActive = true; image.accessibilityLabel = "\(name) wallpaper"
                stack.addArrangedSubview(image)
                button("Use \(name)") { [weak self] in
                    guard let self = self else { return }; self.store.update { $0.wallpaper = index }; Motion.tap(self.store)
                    self.message("Wallpaper saved", "\(name) is now your simulated Home Screen wallpaper.")
                }
            }
        case "health":
            caption.text = "PUBLIC DEVICE INFORMATION"
            let label = Palette.label("", size: 25, weight: .light); clock = label; stack.addArrangedSubview(label); refreshTime()
            body("Network availability describes the current route. It does not expose Wi-Fi passwords or control radios.", size: 15)
        case "links", "safari":
            caption.text = "PERMITTED PUBLIC LINKS"
            body("Open a supported application outside iOS26 Legacy. Return using iOS navigation or the physical Home button.", size: 16)
            for link in PermittedLink.allCases { permitted(link) }
        case "phone":
            caption.text = "PUBLIC PHONE URL · USER-INITIATED"
            let field = UITextField(); field.borderStyle = .roundedRect
            field.backgroundColor = UIColor.white.withAlphaComponent(0.1); field.textColor = .white
            field.attributedPlaceholder = NSAttributedString(string: "Phone number", attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.65)])
            field.keyboardType = .phonePad; field.heightAnchor.constraint(equalToConstant: 52).isActive = true
            field.accessibilityLabel = "Phone number"; numberField = field; stack.addArrangedSubview(field)
            button("Open Phone") { [weak self] in self?.callNumber() }
            body("iOS handles the call confirmation. No calls are placed in the background.", size: 15)
        case "messages":
            caption.text = "SAMPLE CONVERSATIONS"
            card("Alex · Sample", "See you by the waterfront at six.")
            card("Weekend plans · Sample", "A little sun, a little sea.")
            permitted(.messages)
        case "weather":
            caption.text = "SAMPLE WEATHER · NOT A LIVE FORECAST"
            body("26°", size: 88); body("Mostly sunny\nH: 28°  L: 22°", size: 26)
            card("A gentle afternoon", "Now 26°     3 PM 27°     4 PM 25°\nAll values are demonstration data.")
        case "camera":
            caption.text = "CAMERA-STYLE PREVIEW · SAMPLE IMAGE"
            let image = UIImageView(image: Wallpaper.image(size: CGSize(width: 320, height: 300), theme: store.preferences.wallpaper))
            image.heightAnchor.constraint(equalToConstant: 280).isActive = true; image.contentMode = .scaleAspectFill; image.clipsToBounds = true; image.layer.cornerRadius = 24
            stack.addArrangedSubview(image)
            button("Capture sample") { [weak self] in
                guard let self = self else { return }; Motion.tap(self.store)
                self.message("Sample captured", "This is a camera interface preview. No camera or photo library access is requested.")
            }
        case "music":
            caption.text = "DEMO PLAYER · NO AUDIO PLAYBACK"
            card("Glass Waves", "Legacy Sessions\nA visual player concept")
            button("Play / Pause demo") { [weak self] in
                guard let self = self else { return }; self.demoPlaying.toggle(); Motion.tap(self.store)
                self.caption.text = self.demoPlaying ? "PLAYING · VISUAL DEMO ONLY" : "PAUSED · VISUAL DEMO ONLY"
            }
            permitted(.spotify)
        case "maps":
            caption.text = "PUBLIC MAPS LINK"
            body("Find your next place.", size: 35); body("Open Apple Maps to search Manila. This app does not request or track your location.", size: 17)
            permitted(.maps)
        default:
            caption.text = "ON THIS DEVICE"
            card("Your local note", String(store.note.prefix(180)))
            body("Preferences and notes are kept in this app’s sandbox. This preview does not browse another app’s files.", size: 16)
        }
    }
    private func buildCalculator() {
        caption.text = "LOCAL CALCULATOR"
        let display = Palette.label("0", size: 54, weight: .light)
        display.textAlignment = .right; display.numberOfLines = 1
        display.heightAnchor.constraint(equalToConstant: 73).isActive = true
        display.accessibilityIdentifier = "calculator.display"
        calculatorDisplay = display; stack.addArrangedSubview(display)
        let keys = [["AC", "±", "%", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["0", ".", "="]]
        for rowKeys in keys {
            let row = UIStackView(); row.axis = .horizontal; row.spacing = 10; row.distribution = .fillEqually
            for (column, key) in rowKeys.enumerated() {
                let button = ActionButton(key) { [weak self] in
                    guard let self = self else { return }; self.calculator.press(key); self.calculatorDisplay?.text = self.calculator.display; Motion.tap(self.store)
                }
                button.titleLabel?.font = .systemFont(ofSize: 25, weight: .medium)
                if column == 3 || key == "=" { button.backgroundColor = Palette.accent.withAlphaComponent(0.42) }
                button.accessibilityIdentifier = "calculator.\(key)"
                row.addArrangedSubview(button)
            }
            row.heightAnchor.constraint(equalToConstant: 54).isActive = true; stack.addArrangedSubview(row)
        }
    }
    private func buildCalendar() {
        let calendar = Calendar.current
        let now = Date()
        let format = DateFormatter(); format.dateFormat = "MMMM yyyy"
        body(format.string(from: now), size: 27)
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)), let range = calendar.range(of: .day, in: .month, for: now) else { return }
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let day = calendar.component(.day, from: now)
        let symbols = format.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        for week in -1..<6 {
            let row = UIStackView(); row.axis = .horizontal; row.distribution = .fillEqually
            for index in 0..<7 {
                let value = week * 7 + index - offset + 1
                let text = week == -1 ? symbols[(calendar.firstWeekday - 1 + index) % 7] : (range.contains(value) ? String(value) : "")
                let label = Palette.label(text, size: week == -1 ? 11 : 19, weight: value == day && week >= 0 ? .bold : .regular)
                label.textAlignment = .center
                if value == day && week >= 0 { label.backgroundColor = UIColor.white.withAlphaComponent(0.18); label.layer.cornerRadius = 15; label.clipsToBounds = true }
                row.addArrangedSubview(label)
            }
            row.heightAnchor.constraint(equalToConstant: 34).isActive = true; stack.addArrangedSubview(row)
        }
    }
    func refreshTime() {
        if app.id == "health" { clock?.text = DeviceInfo.shared.summary; return }
        guard app.id == "clock" else { return }
        let format = DateFormatter(); format.timeStyle = .short
        clock?.text = format.string(from: Date())
    }
    func textViewDidChange(_ textView: UITextView) { store.note = textView.text }
    @objc private func endEditing() { view.endEditing(true) }
    @objc private func keyboard(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let local = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - local.minY)
        scroll.contentInset.bottom = overlap
        scroll.scrollIndicatorInsets.bottom = overlap
    }
    private func callNumber() {
        let raw = numberField?.text ?? ""
        let allowed = CharacterSet(charactersIn: "+0123456789")
        guard !raw.isEmpty, raw.count <= 20, raw.unicodeScalars.allSatisfy({ allowed.contains($0) }), raw.filter({ $0 == "+" }).count <= 1,
              (!raw.contains("+") || raw.hasPrefix("+")), raw.contains(where: { "0123456789".contains($0) }),
              let url = URL(string: "tel:" + raw) else { message("Enter a phone number", "Use digits and an optional leading +, up to 20 characters."); return }
        view.endEditing(true)
        guard UIApplication.shared.canOpenURL(url) else { message("Phone unavailable", "This device cannot open a phone link."); return }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            if !success { self?.message("Phone link closed", "The call was cancelled or the link could not be opened.") }
        }
    }
}
