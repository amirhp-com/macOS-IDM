import Foundation
import BDMShared

/// Thread-safe wrapper for XPC reply blocks.
private final class ReplyBox<T>: @unchecked Sendable {
    private let handler: T
    init(_ handler: T) { self.handler = handler }
    var value: T { handler }
}

/// XPC service listener delegate and protocol implementation.
final class DownloaderService: NSObject, NSXPCListenerDelegate, BDMDownloaderProtocol, @unchecked Sendable {
    private let engine = DownloadEngine()
    private var clientConnection: NSXPCConnection?

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: BDMDownloaderProtocol.self)
        newConnection.exportedObject = self

        newConnection.remoteObjectInterface = NSXPCInterface(with: BDMDownloaderClientProtocol.self)

        newConnection.invalidationHandler = { [weak self] in
            self?.clientConnection = nil
        }

        self.clientConnection = newConnection
        newConnection.resume()

        // Push engine completion/failure events to the connected app
        Task { [weak self] in
            await self?.engine.setEventHandler { [weak self] event in
                self?.forward(event)
            }
        }
        return true
    }

    private func forward(_ event: EngineEvent) {
        guard let client = clientConnection?.remoteObjectProxy as? BDMDownloaderClientProtocol else { return }
        switch event {
        case .completed(let id, let path):
            client.downloadCompleted(id: id.uuidString, filePath: path)
        case .failed(let id, let error):
            client.downloadFailed(id: id.uuidString, error: error)
        }
    }

    // MARK: - BDMDownloaderProtocol

    func startDownload(id: String, url: String, destination: String, segments: Int, threadsPerSegment: Int, username: String?, password: String?, reply: @escaping (Bool, String?) -> Void) {
        guard let downloadId = UUID(uuidString: id), let downloadURL = URL(string: url) else {
            reply(false, "Invalid ID or URL")
            return
        }

        let authorization = HTTPAuth.basicHeader(username: username, password: password)
        let box = ReplyBox(reply)
        Task {
            await engine.addDownload(
                id: downloadId,
                url: downloadURL,
                destinationPath: destination,
                segmentCount: segments,
                threadsPerSegment: threadsPerSegment,
                authorization: authorization
            )
            box.value(true, nil)
        }
    }

    func pauseDownload(id: String, reply: @escaping (Bool) -> Void) {
        guard let downloadId = UUID(uuidString: id) else {
            reply(false)
            return
        }
        let box = ReplyBox(reply)
        Task {
            await engine.pause(id: downloadId)
            box.value(true)
        }
    }

    func resumeDownload(id: String, reply: @escaping (Bool) -> Void) {
        guard let _ = UUID(uuidString: id) else {
            reply(false)
            return
        }
        reply(true)
    }

    func cancelDownload(id: String, deleteFile: Bool, reply: @escaping (Bool) -> Void) {
        guard let downloadId = UUID(uuidString: id) else {
            reply(false)
            return
        }
        let box = ReplyBox(reply)
        Task {
            await engine.cancel(id: downloadId, deleteFile: deleteFile)
            box.value(true)
        }
    }

    func getProgress(id: String, reply: @escaping (Data?) -> Void) {
        guard let downloadId = UUID(uuidString: id) else {
            reply(nil)
            return
        }
        let box = ReplyBox(reply)
        Task {
            if let progress = await engine.progress(for: downloadId) {
                let data = try? JSONEncoder().encode(progress)
                box.value(data)
            } else {
                box.value(nil)
            }
        }
    }

    func setGlobalSpeedLimit(bytesPerSecond: Int64, reply: @escaping () -> Void) {
        let box = ReplyBox(reply)
        Task {
            await engine.setSpeedLimit(bytesPerSecond: bytesPerSecond)
            box.value()
        }
    }

    func setMaxConcurrentDownloads(_ count: Int, reply: @escaping () -> Void) {
        let box = ReplyBox(reply)
        Task {
            await engine.setMaxConcurrent(count)
            box.value()
        }
    }

    func setPerDomainConnectionLimit(_ limit: Int, reply: @escaping () -> Void) {
        let box = ReplyBox(reply)
        Task {
            await engine.setPerDomainLimit(limit)
            box.value()
        }
    }

    func headCheck(url: String, reply: @escaping (Data?) -> Void) {
        guard let downloadURL = URL(string: url) else {
            reply(nil)
            return
        }
        let box = ReplyBox(reply)
        Task {
            do {
                let result = try await engine.headCheck(url: downloadURL)
                let data = try JSONEncoder().encode(result)
                box.value(data)
            } catch {
                box.value(nil)
            }
        }
    }
}
