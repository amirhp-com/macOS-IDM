import SwiftUI

/// Segmented control for switching between Detailed / Compact / Minimal views.
struct ViewModeToggle: View {
    @Binding var viewMode: ViewMode

    var body: some View {
        Picker("View", selection: $viewMode) {
            Image(systemName: "list.bullet").tag(ViewMode.detailed)
            Image(systemName: "list.dash").tag(ViewMode.compact)
            Image(systemName: "line.3.horizontal").tag(ViewMode.minimal)
        }
        .pickerStyle(.segmented)
        .frame(width: 100)
    }
}
