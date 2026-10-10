import UIKit

enum Palette {
    static let ink = UIColor(red: 0.07, green: 0.10, blue: 0.18, alpha: 1)
    static let accent = UIColor(red: 0.66, green: 0.87, blue: 1, alpha: 1)
    static func label(_ text: String, size: CGFloat = 16, weight: UIFont.Weight = .regular) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: size, weight: weight)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.numberOfLines = 0
        return label
    }
    static func button(_ title: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 20
        button.addTarget(target, action: action, for: .touchUpInside)
        button.accessibilityLabel = title
        return button
    }
}

final class GlassPane: UIView {
    let content = UIView()
    private let sheen = CAGradientLayer()
    private var blurView: UIVisualEffectView?
    private let radius: CGFloat

    init(radius: CGFloat = 28) {
        self.radius = radius
        super.init(frame: .zero)
        layer.cornerRadius = radius
        layer.masksToBounds = true
        layer.borderWidth = 0.7
        layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        sheen.colors = [UIColor.white.withAlphaComponent(0.25).cgColor,
                        UIColor.white.withAlphaComponent(0.07).cgColor,
                        UIColor.white.withAlphaComponent(0.14).cgColor]
        sheen.locations = [0, 0.52, 1]
        sheen.startPoint = CGPoint(x: 0, y: 0)
        sheen.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(sheen)
        addSubview(content)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(blur: Bool) {
        let opaque = UIAccessibility.isReduceTransparencyEnabled
        backgroundColor = Palette.ink.withAlphaComponent(opaque ? 0.97 : 0.22)
        let enabled = blur && !opaque && !ProcessInfo.processInfo.isLowPowerModeEnabled
        if enabled && blurView == nil {
            let effect = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            insertSubview(effect, at: 0)
            // Keep the sheen above the blur but below readable content.
            sheen.removeFromSuperlayer()
            layer.insertSublayer(sheen, above: effect.layer)
            blurView = effect
        } else if !enabled {
            blurView?.removeFromSuperview()
            blurView = nil
        }
        bringSubviewToFront(content)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        sheen.frame = bounds
        CATransaction.commit()
        content.frame = bounds
        blurView?.frame = bounds
    }
}

enum Wallpaper {
    private static var cache: [String: UIImage] = [:]
    static let names = ["Glacier", "Sunset", "Aurora", "Midnight"]

    static func image(size: CGSize, theme: Int) -> UIImage {
        let key = "\(Int(size.width))x\(Int(size.height))-\(theme)"
        if let image = cache[key] { return image }
        // Static image at 1x; no live gradients, parallax or continuous GPU work.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let ctx = renderer.cgContext
            let themes: [[UIColor]] = [
                [UIColor(red: 0.08, green: 0.19, blue: 0.39, alpha: 1), UIColor(red: 0.26, green: 0.63, blue: 0.82, alpha: 1), UIColor(red: 0.65, green: 0.83, blue: 0.88, alpha: 1)],
                [UIColor(red: 0.30, green: 0.08, blue: 0.29, alpha: 1), UIColor(red: 0.89, green: 0.32, blue: 0.32, alpha: 1), UIColor(red: 0.98, green: 0.70, blue: 0.47, alpha: 1)],
                [UIColor(red: 0.04, green: 0.18, blue: 0.26, alpha: 1), UIColor(red: 0.14, green: 0.63, blue: 0.52, alpha: 1), UIColor(red: 0.43, green: 0.43, blue: 0.77, alpha: 1)],
                [UIColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 1), UIColor(red: 0.14, green: 0.19, blue: 0.32, alpha: 1), UIColor(red: 0.22, green: 0.31, blue: 0.44, alpha: 1)]
            ]
            let colors = themes[min(3, max(0, theme))].map { $0.cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.62, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            for i in 0..<3 {
                let ribbon = UIBezierPath()
                let offset = CGFloat(i) * size.width * 0.25
                ribbon.move(to: CGPoint(x: -80 + offset, y: size.height))
                ribbon.addCurve(to: CGPoint(x: size.width + 80, y: -50 + offset),
                                controlPoint1: CGPoint(x: size.width * 0.18 + offset, y: size.height * 0.27),
                                controlPoint2: CGPoint(x: size.width * 0.8, y: size.height * 0.7 - offset))
                ribbon.addLine(to: CGPoint(x: size.width + 160, y: -30 + offset))
                ribbon.addCurve(to: CGPoint(x: 20 + offset, y: size.height),
                                controlPoint1: CGPoint(x: size.width * 0.68, y: size.height * 0.6 - offset),
                                controlPoint2: CGPoint(x: size.width * 0.35 + offset, y: size.height * 0.37))
                ribbon.close()
                UIColor.white.withAlphaComponent(0.07 + CGFloat(i) * 0.025).setFill()
                ribbon.fill()
                UIColor.white.withAlphaComponent(0.12).setStroke()
                ribbon.lineWidth = 1; ribbon.stroke()
            }
            // A slight dark veil keeps labels readable over every wallpaper.
            UIColor.black.withAlphaComponent(0.13).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        if cache.count > 5 { cache.removeAll() }
        cache[key] = image
        return image
    }
    static func clearCache() { cache.removeAll() }
}

enum IconArt {
    private static let cache = NSCache<NSString, UIImage>()
    static func image(app: LegacyApp, clear: Bool) -> UIImage {
        let day = app.id == "calendar" ? Calendar.current.component(.day, from: Date()) : 0
        let key = "\(app.id)-\(day)-\(clear)-\(UIAccessibility.isReduceTransparencyEnabled)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { renderer in
            let ctx = renderer.cgContext
            let rect = CGRect(x: 0.5, y: 0.5, width: 63, height: 63)
            let shape = UIBezierPath(roundedRect: rect, cornerRadius: 16)
            ctx.saveGState(); shape.addClip()
            let opaque = UIAccessibility.isReduceTransparencyEnabled
            let base = UIColor(hue: app.hue, saturation: clear ? 0.22 : 0.75, brightness: clear ? 0.95 : 0.78, alpha: opaque ? 1 : (clear ? 0.25 : 0.88))
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.white.withAlphaComponent(opaque ? 1 : 0.47).cgColor, base.cgColor, UIColor.white.withAlphaComponent(opaque ? 0.9 : 0.12).cgColor] as CFArray, locations: [0, 0.38, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 64, y: 64), options: [])
            ctx.restoreGState()
            UIColor.white.withAlphaComponent(0.62).setStroke(); shape.lineWidth = 1; shape.stroke()
            ctx.saveGState()
            ctx.translateBy(x: 14, y: 14)
            ctx.scaleBy(x: 0.9, y: 0.9)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setLineWidth(2.4); ctx.setLineCap(.round); ctx.setLineJoin(.round)
            draw(app.glyph, ctx: ctx)
            ctx.restoreGState()
        }
        cache.countLimit = 48
        cache.setObject(image, forKey: key)
        return image
    }

    private static func draw(_ glyph: String, ctx: CGContext) {
        func line(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            ctx.beginPath(); ctx.move(to: first)
            for point in points.dropFirst() { ctx.addLine(to: point) }
            ctx.strokePath()
        }
        func rounded(_ rect: CGRect, _ radius: CGFloat = 4) {
            ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath); ctx.strokePath()
        }
        switch glyph {
        case "chat":
            let p = UIBezierPath(roundedRect: CGRect(x: 3, y: 5, width: 34, height: 25), cornerRadius: 10)
            ctx.addPath(p.cgPath); ctx.fillPath()
            let tail = UIBezierPath(); tail.move(to: CGPoint(x: 10, y: 27)); tail.addLine(to: CGPoint(x: 6, y: 36)); tail.addLine(to: CGPoint(x: 21, y: 28)); tail.close(); ctx.addPath(tail.cgPath); ctx.fillPath()
        case "calendar":
            rounded(CGRect(x: 4, y: 5, width: 32, height: 31)); line([CGPoint(x: 4, y: 13), CGPoint(x: 36, y: 13)])
            for x in [12, 28] { line([CGPoint(x: x, y: 2), CGPoint(x: x, y: 8)]) }
            let text = String(Calendar.current.component(.day, from: Date())) as NSString
            text.draw(in: CGRect(x: 6, y: 15, width: 28, height: 21), withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: UIColor.white, .paragraphStyle: centered()])
        case "flower":
            for i in 0..<8 {
                ctx.saveGState(); ctx.translateBy(x: 20, y: 20); ctx.rotate(by: CGFloat(i) * .pi / 4)
                ctx.setFillColor(UIColor(hue: CGFloat(i) / 8, saturation: 0.32, brightness: 1, alpha: 0.85).cgColor)
                ctx.fillEllipse(in: CGRect(x: -6, y: -18, width: 12, height: 21)); ctx.restoreGState()
            }
        case "camera":
            rounded(CGRect(x: 2, y: 9, width: 36, height: 25), 5)
            line([CGPoint(x: 12, y: 9), CGPoint(x: 14, y: 5), CGPoint(x: 25, y: 5), CGPoint(x: 28, y: 9)])
            ctx.strokeEllipse(in: CGRect(x: 13, y: 14, width: 14, height: 14)); ctx.fillEllipse(in: CGRect(x: 31, y: 13, width: 3, height: 3))
        case "sun":
            ctx.strokeEllipse(in: CGRect(x: 11, y: 11, width: 18, height: 18))
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4
                line([CGPoint(x: 20 + cos(a) * 14, y: 20 + sin(a) * 14), CGPoint(x: 20 + cos(a) * 18, y: 20 + sin(a) * 18)])
            }
        case "clock", "compass", "gear":
            ctx.strokeEllipse(in: CGRect(x: 3, y: 3, width: 34, height: 34))
            if glyph == "clock" { line([CGPoint(x: 20, y: 8), CGPoint(x: 20, y: 20), CGPoint(x: 28, y: 24)]) }
            else if glyph == "gear" {
                ctx.strokeEllipse(in: CGRect(x: 13, y: 13, width: 14, height: 14))
                for i in 0..<8 { let a = CGFloat(i) * .pi / 4; line([CGPoint(x: 20 + cos(a) * 12, y: 20 + sin(a) * 12), CGPoint(x: 20 + cos(a) * 18, y: 20 + sin(a) * 18)]) }
            } else { line([CGPoint(x: 26, y: 9), CGPoint(x: 24, y: 24), CGPoint(x: 9, y: 29), CGPoint(x: 16, y: 16), CGPoint(x: 26, y: 9)]) }
        case "map":
            line([CGPoint(x: 3, y: 8), CGPoint(x: 14, y: 3), CGPoint(x: 26, y: 8), CGPoint(x: 37, y: 3), CGPoint(x: 37, y: 32), CGPoint(x: 26, y: 37), CGPoint(x: 14, y: 32), CGPoint(x: 3, y: 37), CGPoint(x: 3, y: 8)])
            line([CGPoint(x: 14, y: 3), CGPoint(x: 14, y: 32)]); line([CGPoint(x: 26, y: 8), CGPoint(x: 26, y: 37)])
        case "notes":
            rounded(CGRect(x: 5, y: 3, width: 30, height: 34))
            for y in [12, 19, 26] { line([CGPoint(x: 11, y: y), CGPoint(x: 29, y: y)]) }
        case "calculator":
            rounded(CGRect(x: 6, y: 2, width: 28, height: 36)); rounded(CGRect(x: 11, y: 7, width: 18, height: 8), 1)
            for x in [13, 26] { for y in [23, 31] { ctx.fillEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)) } }
        case "folder":
            line([CGPoint(x: 3, y: 11), CGPoint(x: 3, y: 6), CGPoint(x: 16, y: 6), CGPoint(x: 21, y: 11), CGPoint(x: 37, y: 11), CGPoint(x: 37, y: 33), CGPoint(x: 3, y: 33), CGPoint(x: 3, y: 11), CGPoint(x: 37, y: 11)])
        case "heart":
            let p = UIBezierPath(); p.move(to: CGPoint(x: 20, y: 35))
            p.addCurve(to: CGPoint(x: 20, y: 10), controlPoint1: CGPoint(x: -12, y: 13), controlPoint2: CGPoint(x: 6, y: -2))
            p.addCurve(to: CGPoint(x: 20, y: 35), controlPoint1: CGPoint(x: 34, y: -2), controlPoint2: CGPoint(x: 52, y: 13))
            ctx.addPath(p.cgPath); ctx.fillPath()
        case "music":
            line([CGPoint(x: 14, y: 30), CGPoint(x: 14, y: 9), CGPoint(x: 32, y: 5), CGPoint(x: 32, y: 26)])
            ctx.fillEllipse(in: CGRect(x: 5, y: 27, width: 10, height: 7)); ctx.fillEllipse(in: CGRect(x: 23, y: 23, width: 10, height: 7))
        case "link":
            ctx.saveGState(); ctx.translateBy(x: 20, y: 20); ctx.rotate(by: -.pi / 4)
            rounded(CGRect(x: -7, y: -18, width: 14, height: 22), 7); rounded(CGRect(x: -7, y: -4, width: 14, height: 22), 7); ctx.restoreGState()
        case "phone":
            let p = UIBezierPath(); p.move(to: CGPoint(x: 9, y: 3)); p.addCurve(to: CGPoint(x: 37, y: 31), controlPoint1: CGPoint(x: -3, y: 13), controlPoint2: CGPoint(x: 27, y: 44))
            p.addLine(to: CGPoint(x: 30, y: 23)); p.addLine(to: CGPoint(x: 24, y: 28)); p.addCurve(to: CGPoint(x: 12, y: 16), controlPoint1: CGPoint(x: 17, y: 26), controlPoint2: CGPoint(x: 14, y: 22)); p.addLine(to: CGPoint(x: 17, y: 10)); p.close(); ctx.addPath(p.cgPath); ctx.fillPath()
        default: break
        }
    }
    private static func centered() -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }
}

final class AppIconButton: UIControl {
    let app: LegacyApp
    var tapped: ((LegacyApp) -> Void)?
    private let picture = UIImageView()
    private let caption: UILabel
    private let showLabel: Bool

    init(app: LegacyApp, clear: Bool, showLabel: Bool = true) {
        self.app = app; self.showLabel = showLabel
        caption = Palette.label(app.title, size: 11, weight: .medium)
        super.init(frame: .zero)
        picture.image = IconArt.image(app: app, clear: clear)
        picture.contentMode = .scaleAspectFit
        caption.textAlignment = .center; caption.numberOfLines = 1
        addSubview(picture); addSubview(caption)
        caption.isHidden = !showLabel
        addTarget(self, action: #selector(pressed), for: .touchUpInside)
        accessibilityLabel = app.title
        accessibilityIdentifier = "app.\(app.id)"
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isHighlighted: Bool {
        didSet {
            Motion.animate { self.picture.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.91, y: 0.91) : .identity }
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(64, min(bounds.width - 8, bounds.height - (showLabel ? 20 : 0)))
        picture.frame = CGRect(x: (bounds.width - side) / 2, y: 0, width: side, height: side)
        caption.frame = CGRect(x: 0, y: side + 5, width: bounds.width, height: 15)
    }
    @objc private func pressed() { tapped?(app) }
    func refresh(clear: Bool) { picture.image = IconArt.image(app: app, clear: clear) }
}
