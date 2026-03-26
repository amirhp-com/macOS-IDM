import Foundation

/// XPC protocol: app → download service
@objc public protocol BDMDownloaderProtocol {
    func startDownload(
        id: String,
        url: String,
        destination: String,
        segments: Int,
        threadsPerSegment: Int,
        reply: @escaping (Bool, String?) -> Void
    )

    func pauseDownload(id: String, reply: @escaping (Bool) -> Void)
    func resumeDownload(id: String, reply: @escaping (Bool) -> Void)
    func cancelDownload(id: String, deleteFile: Bool, reply: @escaping (Bool) -> Void)
    func getProgress(id: String, reply: @escaping (Data?) -> Void)
    func setGlobalSpeedLimit(bytesPerSecond: Int64, reply: @escaping () -> Void)
    func headCheck(url: String, reply: @escaping (Data?) -> Void)
}

/// XPC protocol: download service → app (progress callbacks)
@objc public protocol BDMDownloaderClientProtocol {
    func progressUpdate(_ data: Data)
    func downloadCompleted(id: String, filePath: String)
    func downloadFailed(id: String, error: String)
}
