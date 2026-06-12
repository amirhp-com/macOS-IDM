import SwiftData
import SwiftUI

/// Configures the hosting NSWindow as a chromeless, floating, drag-anywhere
/// widget: no traffic lights, no titlebar, visible on every Space.
private struct MiniWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
    }
}

/// Floating pop-out widget: animated gradient progress ring with a glowing
/// comet head, live name / bytes / speed, draggable anywhere.
struct MiniProgressView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc
    @Environment(\.dismissWindow) private var dismissWindow
    @Query private var downloads: [DownloadItem]

    @State private var hovering = false
    @State private var appeared = false

    private var current: DownloadItem? {
        downloads.first { $0.downloadStatus == .active }
            ?? downloads.first { $0.downloadStatus == .paused }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                background(t)

                Group {
                    if let item = current {
                        activeBody(item, time: t)
                    } else {
                        idleBody
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(width: 330, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay { animatedBorder(t) }
            .overlay(alignment: .topTrailing) { restoreButton }
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)
        }
        .background(MiniWindowConfigurator())
        .gesture(WindowDragGesture())
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }

    // MARK: - Chrome

    private func background(_ t: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
            // Slow-moving aurora sheen
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            BDMColors.accent.opacity(0.10 + 0.05 * sin(t * 0.7)),
                            .clear,
                            BDMColors.accent2.opacity(0.10 + 0.05 * cos(t * 0.5)),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func animatedBorder(_ t: Double) -> some View {
        RoundedRectangle(cornerRadius: 26)
            .strokeBorder(
                AngularGradient(
                    colors: [
                        BDMColors.accent.opacity(0.8),
                        BDMColors.accent2.opacity(0.25),
                        BDMColors.green.opacity(0.55),
                        BDMColors.accent.opacity(0.8),
                    ],
                    center: .center,
                    angle: .degrees((t * 24).truncatingRemainder(dividingBy: 360))
                ),
                lineWidth: 1.5
            )
    }

    private var restoreButton: some View {
        Button {
            restoreMainWindow()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2)
                .padding(6)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(8)
        .opacity(hovering ? 1 : 0)
    }

    // MARK: - Active state

    private func activeBody(_ item: DownloadItem, time t: Double) -> some View {
        HStack(spacing: 16) {
            progressRing(item, time: t)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.system(.callout, weight: .semibold))
                    .lineLimit(1)

                Text(byteLine(item))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                HStack(spacing: 6) {
                    Image(systemName: item.isActive ? "arrow.down.circle.fill" : "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(item.isActive ? BDMColors.accent : BDMColors.yellow)
                        .symbolEffect(.pulse, options: .repeating, isActive: item.isActive)
                    Text(item.isActive
                         ? (downloadManager.formattedSpeed(for: item.id) ?? "…")
                         : loc.t("status.paused"))
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .contentTransition(.numericText())
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Ring with rotating angular gradient and a glowing comet head at the tip.
    private func progressRing(_ item: DownloadItem, time t: Double) -> some View {
        let progress = max(0.02, item.progressFraction)
        let rotation = Angle.degrees((t * 50).truncatingRemainder(dividingBy: 360))
        let pulse = 0.5 + 0.5 * sin(t * 2.4)
        let tipAngle = Angle.degrees(progress * 360 - 90)

        return ZStack {
            Circle()
                .stroke(BDMColors.surface3.opacity(0.9), lineWidth: 7)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [BDMColors.accent, BDMColors.accent2, BDMColors.green, BDMColors.accent],
                        center: .center,
                        angle: rotation
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: BDMColors.accent.opacity(0.35 + 0.3 * pulse), radius: 6 + 4 * pulse)

            // Comet head at the progress tip
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .shadow(color: BDMColors.accent, radius: 4 + 2 * pulse)
                .offset(
                    x: 34 * cos(tipAngle.radians),
                    y: 34 * sin(tipAngle.radians)
                )

            Text("\(Int(item.progressFraction * 100))%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: 72, height: 72)
    }

    private func byteLine(_ item: DownloadItem) -> String {
        let done = ByteCountFormatter.string(fromByteCount: item.downloadedBytes, countStyle: .file)
        let remaining = ByteCountFormatter.string(
            fromByteCount: max(0, item.totalBytes - item.downloadedBytes),
            countStyle: .file
        )
        return "\(done) ↓ · \(remaining) \(loc.t("mini.remaining"))"
    }

    // MARK: - Idle state

    private var idleBody: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(BDMColors.green)
                .symbolEffect(.bounce, value: current == nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t("mini.idle"))
                    .font(.system(.callout, weight: .semibold))
                Text(loc.t("mini.idle_hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func restoreMainWindow() {
        dismissWindow(id: "mini")
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.isMiniaturized {
            window.deminiaturize(nil)
        }
        if let main = NSApp.windows.first(where: { $0.canBecomeMain }) {
            main.makeKeyAndOrderFront(nil)
        }
    }
}
