import AppKit
import SwiftUI

@MainActor
final class FocusToken: ObservableObject {
    @Published private(set) var value = 0

    func requestFocus() {
        value += 1
    }
}

struct QuickPadView: View {
    @Binding var draft: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @ObservedObject var focusToken: FocusToken
    @ObservedObject var presenter: PanelPresenter
    let tagSuggestions: (String) -> [String]
    @State private var previewImage: PastedImage?
    @StateObject private var suggestionModel = TagSuggestionModel()

    private var bottomCornerRadius: CGFloat { 26 }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: bottomCornerRadius,
            bottomTrailingRadius: bottomCornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HashtagTextEditor(
                text: $draft,
                focusTrigger: focusToken.value,
                onPasteImage: { data in
                    presenter.draftImages.append(PastedImage(data: data))
                },
                suggestionsProvider: tagSuggestions,
                suggestionModel: suggestionModel
            )
            .padding(.horizontal, 18)
            // Clear the system menu-bar strip that overlaps the flush top edge.
            .padding(.top, presenter.notchSize.height + 8)
            .padding(.bottom, 8)

            if !suggestionModel.items.isEmpty {
                suggestionBar
                    .padding(.bottom, 8)
            }

            if !presenter.draftImages.isEmpty {
                thumbnailStrip
                    .padding(.bottom, 8)
            }

            controlBar
                .frame(height: 30)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
        }
        .frame(width: presenter.boxSize.width, height: presenter.boxSize.height, alignment: .top)
        .background(Color(white: 0.05))
        .overlay {
            if let previewImage {
                ImagePreviewOverlay(data: previewImage.data) {
                    self.previewImage = nil
                }
            }
        }
        .clipShape(panelShape)
        .overlay {
            panelShape
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .scaleEffect(presenter.isExpanded ? 1 : 0.2, anchor: .top)
        .offset(y: presenter.isExpanded ? 0 : -(presenter.notchSize.height + 12))
        .opacity(presenter.isExpanded ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .ignoresSafeArea(.all)
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Spacer(minLength: 0)

            Button(action: pasteClipboard) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Use clipboard")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onSave) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
        }
    }

    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(suggestionModel.items.enumerated()), id: \.element) { index, tag in
                    Button {
                        suggestionModel.accept(tag)
                    } label: {
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.system(size: 12, weight: .medium))
                            if index == 0 {
                                Text("⇥")
                                    .font(.system(size: 10, weight: .semibold))
                                    .opacity(0.6)
                            }
                        }
                        .foregroundStyle(Color(nsColor: HashtagTextEditor.accent))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay {
                            Capsule().stroke(Color(nsColor: HashtagTextEditor.accent).opacity(0.3), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 28)
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presenter.draftImages) { item in
                    if let nsImage = NSImage(data: item.data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onTapGesture {
                                previewImage = item
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(.white.opacity(0.15), lineWidth: 1)
                            }
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    presenter.draftImages.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white, .black.opacity(0.55))
                                }
                                .buttonStyle(.plain)
                                .padding(2)
                            }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 60)
    }

    private func pasteClipboard() {
        let pasteboard = NSPasteboard.general

        if let pastedImages = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] {
            for image in pastedImages {
                if let data = QuickPadView.pngData(from: image) {
                    presenter.draftImages.append(PastedImage(data: data))
                }
            }
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            if draft.isEmpty {
                draft = text
            } else {
                draft += "\n" + text
            }
        }
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
