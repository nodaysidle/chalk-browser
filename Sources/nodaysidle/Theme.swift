import SwiftUI

/// Nodaysidle void — warm charcoal, not pure black. One palette for the whole app.
enum Nodaysidle {
    enum ColorToken {
        static let void = Color(red: 0.082, green: 0.082, blue: 0.088)       // #151518
        static let chrome = Color(red: 0.102, green: 0.102, blue: 0.108)      // #1a1a1b
        static let surface = Color(red: 0.125, green: 0.125, blue: 0.133)     // #202022
        static let elevated = Color(red: 0.149, green: 0.149, blue: 0.157)   // #262628
        static let line = Color.white.opacity(0.09)
        static let lineStrong = Color.white.opacity(0.14)
        static let text = Color(red: 0.91, green: 0.91, blue: 0.925)         // #e8e8ec
        static let muted = Color(red: 0.58, green: 0.58, blue: 0.60)         // #949499
        static let quiet = Color(red: 0.42, green: 0.42, blue: 0.44)         // #6b6b70
        static let accent = Color(red: 0.82, green: 0.82, blue: 0.84)        // #d1d1d6
        static let danger = Color(red: 0.78, green: 0.42, blue: 0.42)
    }

    enum Metric {
        static let tabBarHeight: CGFloat = 36
        static let toolbarHeight: CGFloat = 40
        static let pillRadius: CGFloat = 999
        static let controlRadius: CGFloat = 8
        static let iconSize: CGFloat = 15
        static let chromeHeight: CGFloat = tabBarHeight + toolbarHeight + 1
    }

    enum Copy {
        static let searchPlaceholder = "Search or type a URL…"
    }

    enum Symbol {
        static let home = "house"
        static let back = "chevron.left"
        static let forward = "chevron.right"
        static let reload = "arrow.clockwise"
        static let stop = "xmark"
        static let newTab = "plus"
        static let closeTab = "xmark"
        static let search = "magnifyingglass"
        static let lock = "lock.fill"
        static let menu = "gearshape"
        // Find bar
        static let findNext = "chevron.down"
        static let findPrev = "chevron.up"
        static let findDismiss = "xmark.circle.fill"
        // Zoom
        static let zoomIn = "plus.magnifyingglass"
        static let zoomOut = "minus.magnifyingglass"
        static let zoomReset = "1.magnifyingglass"
    }
}

struct NodaysidleIcon: View {
    let name: String
    var size: CGFloat = Nodaysidle.Metric.iconSize

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.monochrome)
    }
}

struct NodaysidleGhostButton: View {
    let symbol: String
    var helpText: String? = nil
    var accessibilityLabel: String? = nil
    var disabled: Bool = false
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        let highlighted = (hovering || focused) && !disabled
        let button = Button(action: action) {
            NodaysidleIcon(name: symbol)
                .frame(width: 30, height: 30)
                .background(highlighted ? Nodaysidle.ColorToken.surface : Color.clear)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(focused ? Nodaysidle.ColorToken.accent : .clear, lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .foregroundStyle(disabled ? Nodaysidle.ColorToken.quiet.opacity(0.35) : Nodaysidle.ColorToken.muted)
        .disabled(disabled)
        .onHover { hovering = $0 }

        Group {
            if let helpText, !helpText.isEmpty {
                button.help(helpText)
            } else {
                button
            }
        }
        .accessibilityLabel(accessibilityLabel ?? helpText ?? symbol)
    }
}

// MARK: - Middle-click gesture

extension View {
    /// Fires `action` on middle-click (button 3).
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        background(MiddleClickHelper(action: action))
    }
}

private struct MiddleClickHelper: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> _MiddleClickView {
        let view = _MiddleClickView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: _MiddleClickView, context: Context) {
        nsView.action = action
    }
}

private final class _MiddleClickView: NSView {
    var action: (() -> Void)?

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 { action?() }
    }
}
