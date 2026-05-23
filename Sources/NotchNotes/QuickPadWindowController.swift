import AppKit
import SwiftData
import SwiftUI

@MainActor
final class QuickPadWindowController {
    private let modelContainer: ModelContainer
    private let panel: QuickPadPanel
    private let focusToken = FocusToken()
    private let presenter = PanelPresenter()
    private var draft = ""
    private var dismissWorkItem: DispatchWorkItem?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.panel = QuickPadPanel()

        let content = QuickPadView(
            draft: Binding(
                get: { [weak self] in self?.draft ?? "" },
                set: { [weak self] in self?.draft = $0 }
            ),
            onSave: { [weak self] in self?.saveDraft() },
            onCancel: { [weak self] in self?.hide() },
            focusToken: focusToken,
            presenter: presenter
        )

        let hostingView = NSHostingView(rootView: content)
        hostingView.safeAreaRegions = []
        panel.contentView = hostingView
        panel.onCancel = { [weak self] in self?.hide() }
    }

    func toggle() {
        presenter.isExpanded ? hide() : show()
    }

    func show() {
        print("Notch Notes: showing quick pad.")
        dismissWorkItem?.cancel()
        positionPanel()
        presenter.isExpanded = false
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        panel.focusPanel()
        focusToken.requestFocus()
        withAnimation(PanelPresenter.transition) {
            presenter.isExpanded = true
        }
    }

    func hide() {
        guard presenter.isExpanded else {
            panel.orderOut(nil)
            return
        }

        withAnimation(PanelPresenter.transition) {
            presenter.isExpanded = false
        }

        let work = DispatchWorkItem { [weak self] in
            self?.panel.orderOut(nil)
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + PanelPresenter.dismissDelay, execute: work)
    }

    private func saveDraft() {
        let trimmedBody = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            hide()
            return
        }

        modelContainer.mainContext.insert(Note(body: trimmedBody))
        try? modelContainer.mainContext.save()
        draft = ""
        hide()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else {
            return
        }

        let frame = screen.frame
        let notch = QuickPadWindowController.notchMetrics(for: screen)
        presenter.notchSize = notch.size

        let width: CGFloat = 560
        let contentHeight: CGFloat = 300
        let height = contentHeight + notch.size.height
        // Flush against the very top edge so the card grows out of the notch.
        let x = notch.centerX - width / 2
        let y = frame.maxY - height
        print("Notch Notes: positioning quick pad at x=\(Int(x)) y=\(Int(y)) w=\(Int(width)) h=\(Int(height)) notch=\(Int(notch.size.width))x\(Int(notch.size.height)).")
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    /// Returns the physical notch size and its horizontal center in screen coordinates.
    /// Falls back to a centered faux-notch size when the display has no notch.
    private static func notchMetrics(for screen: NSScreen) -> (size: CGSize, centerX: CGFloat) {
        let frame = screen.frame
        let fallback = CGSize(width: 200, height: 32)

        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let notchWidth = frame.width - left.width - right.width
            if notchWidth > 0 {
                let centerX = frame.minX + left.width + notchWidth / 2
                return (CGSize(width: notchWidth, height: topInset), centerX)
            }
        }

        return (fallback, frame.midX)
    }
}

@MainActor
final class PanelPresenter: ObservableObject {
    @Published var isExpanded = false
    @Published var notchSize = CGSize(width: 200, height: 32)

    static let transition: Animation = .spring(response: 0.4, dampingFraction: 0.78)
    static let dismissDelay: TimeInterval = 0.32
}

final class QuickPadPanel: NSPanel {
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 360),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Allow the panel to extend over the menu bar instead of being pushed below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    func focusPanel() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.makeKey()
            self.contentView?.window?.recalculateKeyViewLoop()
        }
    }
}
