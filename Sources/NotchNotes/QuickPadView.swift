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
    @FocusState private var isEditorFocused: Bool

    private var bottomCornerRadius: CGFloat { 26 }

    var body: some View {
        VStack(spacing: 0) {
            header
                // Sit the controls at menu-bar level, vertically centered in the top strip.
                .frame(height: max(presenter.notchSize.height, 24))
                .padding(.top, 1)
                .padding(.horizontal, 18)

            TextEditor(text: $draft)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .tint(.white)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomCornerRadius,
                bottomTrailingRadius: bottomCornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color(white: 0.05))
        }
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomCornerRadius,
                bottomTrailingRadius: bottomCornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .scaleEffect(presenter.isExpanded ? 1 : 0.2, anchor: .top)
        .offset(y: presenter.isExpanded ? 0 : -(presenter.notchSize.height + 12))
        .opacity(presenter.isExpanded ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .ignoresSafeArea(.all)
        .onAppear {
            isEditorFocused = true
        }
        .onChange(of: focusToken.value) {
            isEditorFocused = true
        }
    }

    private var header: some View {
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

    private func pasteClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.isEmpty else {
            return
        }

        if draft.isEmpty {
            draft = text
        } else {
            draft += "\n" + text
        }
        isEditorFocused = true
    }
}
