import UIKit

final class ControlState {
    var toggles = [false, true, true, true, false, false]
    var volume: CGFloat = 0.6
    var playing = false
}

final class GlassSlider: UIControl {
    private let track = GlassPane(radius: 27)
    private let fill = UIView()
    private let caption: UILabel
    private let amount = Palette.label("", size: 14, weight: .semibold)
    var value: CGFloat = 0.5 {
        didSet { value = min(1, max(0, value)); amount.text = "\(Int(value * 100))%"; accessibilityValue = amount.text; setNeedsLayout() }
    }
    var changed: ((CGFloat) -> Void)?
    init(title: String) {
        caption = Palette.label(title, size: 13, weight: .semibold)
        super.init(frame: .zero)
        track.configure(blur: false); track.isUserInteractionEnabled = false; addSubview(track)
        fill.backgroundColor = UIColor.white.withAlphaComponent(0.37)
        track.content.addSubview(fill); track.content.addSubview(caption); track.content.addSubview(amount)
        caption.textAlignment = .center; amount.textAlignment = .center
        isAccessibilityElement = true
        accessibilityTraits = [.adjustable]
        accessibilityLabel = title
        accessibilityHint = "Simulated control inside iOS26 Legacy"
        value = 0.5
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews(); track.frame = bounds
        fill.frame = CGRect(x: 0, y: bounds.height * (1 - value), width: bounds.width, height: bounds.height * value)
        caption.frame = CGRect(x: 2, y: bounds.height - 40, width: bounds.width - 4, height: 26)
        amount.frame = CGRect(x: 2, y: 14, width: bounds.width - 4, height: 22)
    }
    private func update(_ touch: UITouch, animated: Bool) {
        value = 1 - touch.location(in: self).y / max(1, bounds.height)
        if animated { Motion.animate { self.layoutIfNeeded() } } else { layoutIfNeeded() }
        changed?(value); sendActions(for: .valueChanged)
    }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { update(touch, animated: true); return true }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { update(touch, animated: false); return true }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) { if let touch = touch { update(touch, animated: true) } }
    override func accessibilityIncrement() { value += 0.1; changed?(value); Motion.animate { self.layoutIfNeeded() } }
    override func accessibilityDecrement() { value -= 0.1; changed?(value); Motion.animate { self.layoutIfNeeded() } }
}

final class ControlCenterViewController: UIViewController {
    let store: LegacyStore
    let state: ControlState
    var brightness: CGFloat = 0.85
    var brightnessChanged: ((CGFloat) -> Void)?
    var done: (() -> Void)?
    private let scroll = UIScrollView()
    private let heading = Palette.label("Control Center", size: 29, weight: .bold)
    private let subtitle = Palette.label("SIMULATED CONTROLS", size: 11, weight: .semibold)
    private let connectivity = GlassPane()
    private let music = GlassPane()
    private let musicTitle = Palette.label("Glass Waves\nDemo player", size: 20, weight: .semibold)
    private let hint = Palette.label("Connectivity and volume are demos. Brightness dims only this app. No device settings are changed.", size: 13)
    private var toggleButtons: [UIButton] = []
    private var playButton: UIButton!
    private var closeButton: UIButton!
    private let light = GlassSlider(title: "Light")
    private let volume = GlassSlider(title: "Volume")
    private let names = ["Airplane", "Wi-Fi", "Bluetooth", "Cellular", "Focus", "Rotation"]

    init(store: LegacyStore, state: ControlState) {
        self.store = store; self.state = state
        super.init(nibName: nil, bundle: nil); title = "Controls"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "controls.screen"
        view.backgroundColor = Palette.ink.withAlphaComponent(0.65)
        view.addSubview(scroll)
        for item in [heading, subtitle, connectivity, music, light, volume, hint] as [UIView] { scroll.addSubview(item) }
        closeButton = Palette.button("Done", target: self, action: #selector(close)); scroll.addSubview(closeButton)
        music.content.addSubview(musicTitle)
        playButton = Palette.button("Play", target: self, action: #selector(play)); music.content.addSubview(playButton)
        for i in 0..<6 {
            let button = Palette.button(names[i], target: self, action: #selector(toggle(_:)))
            button.tag = i; button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            connectivity.content.addSubview(button); toggleButtons.append(button)
        }
        light.value = brightness; volume.value = state.volume
        light.changed = { [weak self] in self?.brightnessChanged?($0) }
        volume.changed = { [weak self] in self?.state.volume = $0 }
        refreshGlass(); refreshButtons()
        playButton.setTitle(state.playing ? "Pause" : "Play", for: .normal)
    }
    func refreshGlass() {
        guard isViewLoaded else { return }
        connectivity.configure(blur: store.preferences.blur)
        music.configure(blur: false)
    }
    private func refreshButtons() {
        for (i, button) in toggleButtons.enumerated() {
            button.backgroundColor = state.toggles[i] ? Palette.accent.withAlphaComponent(0.58) : UIColor.white.withAlphaComponent(0.08)
            button.accessibilityValue = state.toggles[i] ? "On, simulated" : "Off, simulated"
            button.setTitle(names[i] + (state.toggles[i] ? " ●" : " ○"), for: .normal)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scroll.frame = view.bounds
        let width = view.bounds.width; let inset: CGFloat = 18; let gap: CGFloat = 12
        heading.frame = CGRect(x: inset, y: 15, width: width - 110, height: 39)
        subtitle.frame = CGRect(x: inset + 1, y: 54, width: width - 36, height: 18)
        closeButton.frame = CGRect(x: width - 81, y: 17, width: 63, height: 36)
        let leftWidth = (width - inset * 2 - gap) * 0.56
        connectivity.frame = CGRect(x: inset, y: 86, width: leftWidth, height: 183)
        music.frame = CGRect(x: connectivity.frame.maxX + gap, y: 86, width: width - inset - connectivity.frame.maxX - gap, height: 183)
        for (i, button) in toggleButtons.enumerated() {
            let cell = (leftWidth - 24) / 2
            button.frame = CGRect(x: 8 + CGFloat(i % 2) * (cell + 8), y: 13 + CGFloat(i / 2) * 55, width: cell, height: 47)
        }
        musicTitle.frame = CGRect(x: 16, y: 21, width: music.bounds.width - 32, height: 77)
        playButton.frame = CGRect(x: 12, y: 119, width: music.bounds.width - 24, height: 43)
        let sliderWidth = (width - 2 * inset - gap) / 2
        light.frame = CGRect(x: inset, y: 283, width: sliderWidth, height: 172)
        volume.frame = CGRect(x: inset + sliderWidth + gap, y: 283, width: sliderWidth, height: 172)
        hint.frame = CGRect(x: inset + 2, y: 470, width: width - 2 * inset - 4, height: 67)
        scroll.contentSize = CGSize(width: width, height: 550)
    }
    @objc private func toggle(_ button: UIButton) {
        state.toggles[button.tag].toggle(); Motion.tap(store)
        Motion.animate { self.refreshButtons(); button.transform = CGAffineTransform(scaleX: 1.03, y: 1.03) } completion: { _ in
            Motion.animate { button.transform = .identity }
        }
    }
    @objc private func play() {
        state.playing.toggle(); Motion.tap(store)
        playButton.setTitle(state.playing ? "Pause" : "Play", for: .normal)
        musicTitle.text = state.playing ? "Glass Waves\nPlaying · demo" : "Glass Waves\nDemo player"
    }
    @objc private func close() { done?() }
}
