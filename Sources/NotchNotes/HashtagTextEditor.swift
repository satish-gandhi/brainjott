import AppKit
import SwiftUI

/// Drives the inline tag-suggestion chip bar shown while typing a `#hashtag`.
@MainActor
final class TagSuggestionModel: ObservableObject {
    @Published var items: [String] = []
    var onAccept: (String) -> Void = { _ in }

    func accept(_ tag: String) {
        onAccept(tag)
    }
}

/// A plain-text editor backed by NSTextView that renders body text in white,
/// highlights `#hashtags` with a cyan glow, draws a cyan glowing caret, routes
/// image pastes to `onPasteImage`, and surfaces tag suggestions while typing.
struct HashtagTextEditor: NSViewRepresentable {
    @Binding var text: String
    var focusTrigger: Int
    var onPasteImage: (Data) -> Void
    var suggestionsProvider: (String) -> [String]
    var suggestionModel: TagSuggestionModel

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

        let coordinator = context.coordinator
        coordinator.textView = textView
        textView.onTabComplete = { [weak coordinator] in
            coordinator?.acceptFirstSuggestion() ?? false
        }
        suggestionModel.onAccept = { [weak coordinator] tag in
            coordinator?.acceptSuggestion(tag)
        }

        textView.string = text
        coordinator.applyHighlighting()
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
            context.coordinator.updateSuggestions()
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

        private static let tagChars = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
        )
        private static let disallowedBeforeHash = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-#"
        )

        init(_ parent: HashtagTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else {
                return
            }
            parent.text = textView.string
            applyHighlighting()
            updateSuggestions()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateSuggestions()
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

        // MARK: - Suggestions

        /// The `#hashtag` token the caret is currently inside, if any.
        private struct HashtagContext {
            let query: String
            let queryRange: NSRange
        }

        private func hashtagContext() -> HashtagContext? {
            guard let textView else {
                return nil
            }
            let selection = textView.selectedRange()
            guard selection.length == 0 else {
                return nil
            }

            let string = textView.string as NSString
            var start = selection.location
            while start > 0, isTagCharacter(string.character(at: start - 1)) {
                start -= 1
            }

            // Must be immediately preceded by '#'.
            guard start > 0, string.character(at: start - 1) == hashScalar else {
                return nil
            }

            // The '#' itself must not be preceded by a word character.
            let hashLocation = start - 1
            if hashLocation > 0,
               isDisallowedBeforeHash(string.character(at: hashLocation - 1)) {
                return nil
            }

            let queryRange = NSRange(location: start, length: selection.location - start)
            return HashtagContext(query: string.substring(with: queryRange), queryRange: queryRange)
        }

        func updateSuggestions() {
            guard let context = hashtagContext() else {
                if !parent.suggestionModel.items.isEmpty {
                    parent.suggestionModel.items = []
                }
                return
            }
            parent.suggestionModel.items = parent.suggestionsProvider(context.query)
        }

        func acceptSuggestion(_ tag: String) {
            guard let textView, let context = hashtagContext() else {
                return
            }

            if textView.shouldChangeText(in: context.queryRange, replacementString: tag) {
                textView.replaceCharacters(in: context.queryRange, with: tag)
                textView.didChangeText()
            }

            let caret = context.queryRange.location + (tag as NSString).length
            textView.setSelectedRange(NSRange(location: caret, length: 0))
            parent.text = textView.string
            parent.suggestionModel.items = []
            applyHighlighting()
            textView.window?.makeFirstResponder(textView)
        }

        func acceptFirstSuggestion() -> Bool {
            guard let first = parent.suggestionModel.items.first else {
                return false
            }
            acceptSuggestion(first)
            return true
        }

        private var hashScalar: unichar { unichar(UnicodeScalar("#").value) }

        private func isTagCharacter(_ unit: unichar) -> Bool {
            guard let scalar = Unicode.Scalar(unit) else { return false }
            return Coordinator.tagChars.contains(scalar)
        }

        private func isDisallowedBeforeHash(_ unit: unichar) -> Bool {
            guard let scalar = Unicode.Scalar(unit) else { return false }
            return Coordinator.disallowedBeforeHash.contains(scalar)
        }
    }
}

/// NSTextView that draws a cyan, glowing insertion point, diverts image pastes
/// to a closure, and lets Tab accept the first tag suggestion.
final class GlowingTextView: NSTextView {
    var onPasteImage: ((Data) -> Void)?
    var onTabComplete: (() -> Bool)?

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

    override func keyDown(with event: NSEvent) {
        // Tab accepts the first tag suggestion when the chip bar is showing.
        if event.charactersIgnoringModifiers == "\t",
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
           onTabComplete?() == true {
            return
        }
        super.keyDown(with: event)
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
