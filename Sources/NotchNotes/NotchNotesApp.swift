import AppKit
import SwiftData
import SwiftUI

@main
struct NotchNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer
    @StateObject private var appController: AppController
    @Environment(\.openWindow) private var openWindow

    init() {
        do {
            let schema = Schema([Note.self])
            let configuration = ModelConfiguration(schema: schema)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container
            _appController = StateObject(wrappedValue: AppController(modelContainer: container))
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("Library", id: "library") {
            LibraryView()
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 980, height: 640)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
        }

        MenuBarExtra("Notch Notes", systemImage: "note.text") {
            Button("Open Quick Note") {
                appController.toggleQuickPad()
            }
            .keyboardShortcut("n", modifiers: [.option])

            Button("Open Library") {
                openWindow(id: "library")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            SettingsLink()

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@MainActor
final class AppController: ObservableObject {
    private let quickPadController: QuickPadWindowController
    private var hotKey: GlobalHotKey?

    init(modelContainer: ModelContainer) {
        self.quickPadController = QuickPadWindowController(modelContainer: modelContainer)
        self.hotKey = GlobalHotKey { [weak self] in
            self?.toggleQuickPad()
        }
        showQuickPadOnLaunch()
    }

    func toggleQuickPad() {
        quickPadController.toggle()
    }

    func showQuickPadOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.quickPadController.show()
        }
    }
}
