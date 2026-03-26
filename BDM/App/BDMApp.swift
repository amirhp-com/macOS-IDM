import SwiftUI
import SwiftData

@main
struct BDMApp: App {
    @State private var appearance = AppearanceManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appearance)
                .preferredColorScheme(appearance.theme.colorScheme)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.automatic) // Liquid Glass chrome on macOS 26
        .modelContainer(for: [
            DownloadItem.self,
            DownloadSegment.self,
            DownloadThreadRange.self,
            RoutingRule.self,
        ])

        Settings {
            SettingsView()
                .environment(appearance)
                .frame(minWidth: 600, minHeight: 450)
        }
    }
}
