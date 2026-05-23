import AppKit
import SwiftUI

/// A plain-text editor backed by NSTextView that renders body text in white,
/// highlights `#hashtags` with a cyan glow, and draws a cyan glowing caret.
/// Image pastes are routed to `onPasteImage` instead of being inserted as text.
struct HashtagTextEditor: NSViewRepresentable {
    @Binding var text: String
    var focusTrigger: Int
    var onPasteImage: (Data) -> Void

    static let accent = NSColor(red: 0.20, green: 0.92, blue: 1.0, alpha: 1.0)
    static let bodyColor = NSColor.white
    static let font = NSFont.systemFont(ofSize: 15)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = GlowingTextView()
        textView.delegate = context.coordinator
        textView.onPasteImage = onPasteImage
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = HashtagTextEditor.font
        textView.textColor = HashtagTextEditor.bodyColor
        textView.insertionPointColor = HashtagTextEditor.accent
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        context.coordinator.textView = textView
        textView.string = text
        context.coordinator.applyHighlighting()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else {
            return
        }

        textView.onPasteImage = onPasteImage

        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
            context.coordinator.applyHighlighting()
        }

        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: HashtagTextEditor
        weak var textView: GlowingTextView?
        var lastFocusTrigger = Int.min

        init(_ parent: HashtagTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else {
                return
            }
            parent.text = textView.string
            applyHighlighting()
        }

        func applyHighlighting() {
            guard let textView, let storage = textView.textStorage else {
                return
            }

            let string = textView.string as NSString
            let fullRange = NSRange(location: 0, length: string.length)

            storage.beginEditing()
            storage.removeAttribute(.shadow, range: fullRange)
            storage.addAttribute(.foregroundColor, value: HashtagTextEditor.bodyColor, range: fullRange)
            storage.addAttribute(.font, value: HashtagTextEditor.font, range: fullRange)

            for range in HashtagExtractor.hashtagRanges(in: textView.string) {
                storage.addAttribute(.foregroundColor, value: HashtagTextEditor.accent, range: range)
                let glow = NSShadow()
                glow.shadowColor = HashtagTextEditor.accent.withAlphaComponent(0.9)
                glow.shadowBlurRadius = 5
                glow.shadowOffset = .zero
                storage.addAttribute(.shadow, value: glow, range: range)
            }
            storage.endEditing()
        }
    }
}

/// NSTextView that draws a cyan, glowing insertion point and diverts image
/// pastes to a closure.
final class GlowingTextView: NSTextView {
    var onPasteImage: ((Data) -> Void)?

    // This app has no Edit menu (it runs as a menu-bar accessory), so the
    // standard editing shortcuts aren't delivered via menu key equivalents.
    // Handle them here so Cmd-V/C/X/A and undo work inside the panel.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()

        if flags == .command {
            switch key {
            case "v": paste(nil); return true
            case "c": copy(nil); return true
            case "x": cut(nil); return true
            case "a": selectAll(nil); return true
            case "z": undoManager?.undo(); return true
            default: break
            }
        } else if flags == [.command, .shift], key == "z" {
            undoManager?.redo()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        let hasText = (pasteboard.string(forType: .string)?.isEmpty == false)

        if !hasText,
           let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
           !images.isEmpty {
            for image in images {
                if let data = GlowingTextView.pngData(from: image) {
                    onPasteImage?(data)
                }
            }
            return
        }

        super.paste(sender)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag else {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
            return
        }

        let cyan = HashtagTextEditor.accent
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = cyan.withAlphaComponent(0.95)
        glow.shadowBlurRadius = 6
        glow.shadowOffset = .zero
        glow.set()
        cyan.set()
        rect.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    // Expand the dirty region so the caret glow isn't clipped or left behind
    // when the insertion point blinks.
    override func setNeedsDisplay(_ invalidRect: NSRect) {
        super.setNeedsDisplay(invalidRect.insetBy(dx: -7, dy: -7))
    }

    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
