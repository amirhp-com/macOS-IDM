import Foundation
import BDMShared

/// App-side XPC client for communicating with the BDMDownloader service.
@Observable
final class XPCClient: @unchecked Sendable {
    private var connection: NSXPCConnection?
    private(set) var isConnected = false

    func connect() {
        let conn = NSXPCConnection(serviceName: "com.amirhpcom.bdm.downloader")
        conn.remoteObjectInterface = NSXPCInterface(with: BDMDownloaderProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: BDMDownloaderClientProtocol.self)
        conn.exportedObject = XPCClientDelegate()

        conn.invalidationHandler = { [weak self] in
            self?.isConnected = false
            self?.connection = nil
        }

        conn.interruptionHandler = { [weak self] in
            self?.isConnected = false
        }

        conn.resume()
        self.connection = conn
        self.isConnected = true
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
        isConnected = false
    }

    private var proxy: BDMDownloaderProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { error in
            print("[BDM] XPC error: \(error)")
        } as? BDMDownloaderProtocol
    }

    func startDownload(id: UUID, url: String, destination: String, segments: Int, threadsPerSegment: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            proxy?.startDownload(id: id.uuidString, url: url, destination: destination, segments: segments, threadsPerSegment: threadsPerSegment) { success, error in
                if let error { print("[BDM] Start failed: \(error)") }
                continuation.resume(returning: success)
            }
        }
    }

    func pauseDownload(id: UUID) async -> Bool {
        await withCheckedContinuation { continuation in
            proxy?.pauseDownload(id: id.uuidString) { success in
                continuation.resume(returning: success)
            }
        }
    }

    func cancelDownload(id: UUID, deleteFile: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            proxy?.cancelDownload(id: id.uuidString, deleteFile: deleteFile) { success in
                continuation.resume(returning: success)
            }
        }
    }

    func getProgress(id: UUID) async -> DownloadProgress? {
        await withCheckedContinuation { continuation in
            proxy?.getProgress(id: id.uuidString) { data in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }
                let progress = try? JSONDecoder().decode(DownloadProgress.self, from: data)
                continuation.resume(returning: progress)
            }
        }
    }

    func headCheck(url: String) async -> HeadCheckResult? {
        await withCheckedContinuation { continuation in
            proxy?.headCheck(url: url) { data in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }
                let result = try? JSONDecoder().decode(HeadCheckResult.self, from: data)
                continuation.resume(returning: result)
            }
        }
    }

    func setSpeedLimit(bytesPerSecond: Int64) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            proxy?.setGlobalSpeedLimit(bytesPerSecond: bytesPerSecond) {
                continuation.resume()
            }
        }
    }
}

/// Handles callbacks from XPC service → app.
final class XPCClientDelegate: NSObject, BDMDownloaderClientProtocol, @unchecked Sendable {
    func progressUpdate(_ data: Data) {
        guard let progress = try? JSONDecoder().decode(DownloadProgress.self, from: data) else { return }
        // TODO: Post notification to update UI
        _ = progress
    }

    func downloadCompleted(id: String, filePath: String) {
        // TODO: Update SwiftData model, post notification
    }

    func downloadFailed(id: String, error: String) {
        // TODO: Update SwiftData model, post notification
    }
}
