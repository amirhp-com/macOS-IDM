import SwiftUI

/// Segmented control for switching between Detailed / Compact / Minimal views.
struct ViewModeToggle: View {
    @Binding var viewMode: ViewMode

    var body: some View {
        Picker("View", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
    }
}
