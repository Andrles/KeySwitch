import AppKit

/// Native backdrop material with an explicit opaque accessibility fallback.
/// Content is never faded: only the surface behind it changes.
class MaterialSurface: NSView {
    enum Role { case window, sidebar, group, popover }
    struct Accessibility {
        var reduceTransparency: Bool
        var increaseContrast: Bool
        static var system: Self {
            Self(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                 increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
        }
    }

    let effect = NSVisualEffectView()
    private let role: Role
    private let accessibility: () -> Accessibility
    private var displayObserver: NSObjectProtocol?

    init(role: Role, accessibility: @escaping () -> Accessibility = { .system }) {
        self.role = role
        self.accessibility = accessibility
        super.init(frame: .zero)
        wantsLayer = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        effect.state = .active
        effect.blendingMode = role == .window || role == .popover ? .behindWindow : .withinWindow
        switch role {
        case .window: effect.material = .underWindowBackground
        case .sidebar: effect.material = .sidebar
        case .group: effect.material = .contentBackground
        case .popover: effect.material = .popover
        }
        addSubview(effect)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layer?.cornerRadius = role == .popover ? 16 : role == .group ? 12 : 0
        layer?.masksToBounds = true
        displayObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.refreshMaterial() }
        refreshMaterial()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        if let displayObserver { NSWorkspace.shared.notificationCenter.removeObserver(displayObserver) }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshMaterial()
    }

    func refreshMaterial() {
        let options = accessibility()
        let solid = options.reduceTransparency || options.increaseContrast
        // Groups share the window's material instead of stacking blur layers.
        effect.isHidden = solid || role == .group
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color: NSColor
            if solid { color = role == .group ? .controlBackgroundColor : .windowBackgroundColor }
            else if role == .group { color = NSColor.controlBackgroundColor.withAlphaComponent(0.35) }
            else { color = .clear }
            layer?.backgroundColor = color.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
        layer?.borderWidth = options.increaseContrast ? 1 : role == .popover ? 0.5 : 0
    }
}
