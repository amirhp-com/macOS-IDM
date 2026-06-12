import Foundation
import BDMShared

/// App-side XPC client for communicating with the BDMDownloader service.
@Observable
final class XPCClient: @unchecked Sendable {
    private var connection: NSXPCConnection?
    private(set) var isConnected = false

    /// Service → app event callbacks. Set before calling connect().
    var onCompleted: (@Sendable (_ id: String, _ filePath: String) -> Void)?
    var onFailed: (@Sendable (_ id: String, _ error: String) -> Void)?

    func connect() {
        let conn = NSXPCConnection(serviceName: "com.amirhpcom.bdm.downloader")
        conn.remoteObjectInterface = NSXPCInterface(with: BDMDownloaderProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: BDMDownloaderClientProtocol.self)
        conn.exportedObject = XPCClientDelegate(onCompleted: onCompleted, onFailed: onFailed)

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

    /// Resolves the remote proxy, reconnecting if the connection was dropped.
    private var proxy: BDMDownloaderProtocol? {
        if connection == nil { connect() }
        return connection?.remoteObjectProxyWithErrorHandler { error in
            print("[BDM] XPC error: \(error)")
        } as? BDMDownloaderProtocol
    }

    func startDownload(id: UUID, url: String, destination: String, segments: Int, threadsPerSegment: Int, username: String? = nil, password: String? = nil) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let proxy else {
                continuation.resume(returning: false)
                return
            }
            proxy.startDownload(id: id.uuidString, url: url, destination: destination, segments: segments, threadsPerSegment: threadsPerSegment, username: username, password: password) { success, error in
                if let error { print("[BDM] Start failed: \(error)") }
                continuation.resume(returning: success)
            }
        }
    }

    func pauseDownload(id: UUID) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let proxy else {
                continuation.resume(returning: false)
                return
            }
            proxy.pauseDownload(id: id.uuidString) { success in
                continuation.resume(returning: success)
            }
        }
    }

    func cancelDownload(id: UUID, deleteFile: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let proxy else {
                continuation.resume(returning: false)
                return
            }
            proxy.cancelDownload(id: id.uuidString, deleteFile: deleteFile) { success in
                continuation.resume(returning: success)
            }
        }
    }

    func getProgress(id: UUID) async -> DownloadProgress? {
        await withCheckedContinuation { continuation in
            guard let proxy else {
                continuation.resume(returning: nil)
                return
            }
            proxy.getProgress(id: id.uuidString) { data in
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
            guard let proxy else {
                continuation.resume(returning: nil)
                return
            }
            proxy.headCheck(url: url) { data in
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
            guard let proxy else {
                continuation.resume()
                return
            }
            proxy.setGlobalSpeedLimit(bytesPerSecond: bytesPerSecond) {
                continuation.resume()
            }
        }
    }

    func setMaxConcurrentDownloads(_ count: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let proxy else {
                continuation.resume()
                return
            }
            proxy.setMaxConcurrentDownloads(count) {
                continuation.resume()
            }
        }
    }

    func setPerDomainConnectionLimit(_ limit: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let proxy else {
                continuation.resume()
                return
            }
            proxy.setPerDomainConnectionLimit(limit) {
                continuation.resume()
            }
        }
    }
}

/// Handles callbacks from XPC service → app.
final class XPCClientDelegate: NSObject, BDMDownloaderClientProtocol, @unchecked Sendable {
    private let onCompleted: (@Sendable (String, String) -> Void)?
    private let onFailed: (@Sendable (String, String) -> Void)?

    init(onCompleted: (@Sendable (String, String) -> Void)?, onFailed: (@Sendable (String, String) -> Void)?) {
        self.onCompleted = onCompleted
        self.onFailed = onFailed
    }

    func progressUpdate(_ data: Data) {
        // Progress is polled by DownloadManager; push updates unused for now.
    }

    func downloadCompleted(id: String, filePath: String) {
        onCompleted?(id, filePath)
    }

    func downloadFailed(id: String, error: String) {
        onFailed?(id, error)
    }
}
