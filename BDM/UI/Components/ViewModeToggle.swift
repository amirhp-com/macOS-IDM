import SwiftUI

/// Segmented control for switching between the list view modes.
struct ViewModeToggle: View {
    @Binding var viewMode: ViewMode

    var body: some View {
        Picker("View", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Image(systemName: mode.systemImage)
                    .help(mode.displayName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 170)
    }
}
