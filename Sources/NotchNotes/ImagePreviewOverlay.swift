import AppKit
import SwiftUI

/// A dimmed lightbox that shows a single image scaled to fit its container.
/// Tap the backdrop or the close button to dismiss.
struct ImagePreviewOverlay: View {
    let data: Data
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.82))
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(28)
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .padding(12)
                }
                Spacer()
            }
        }
    }
}
