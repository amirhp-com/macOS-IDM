import Foundation

/// XPC protocol: app → download service
@objc public protocol BDMDownloaderProtocol {
    func startDownload(
        id: String,
        url: String,
        destination: String,
        segments: Int,
        threadsPerSegment: Int,
        username: String?,
        password: String?,
        reply: @escaping (Bool, String?) -> Void
    )

    func pauseDownload(id: String, reply: @escaping (Bool) -> Void)
    func resumeDownload(id: String, reply: @escaping (Bool) -> Void)
    func cancelDownload(id: String, deleteFile: Bool, reply: @escaping (Bool) -> Void)
    func getProgress(id: String, reply: @escaping (Data?) -> Void)
    func setGlobalSpeedLimit(bytesPerSecond: Int64, reply: @escaping () -> Void)
    func setMaxConcurrentDownloads(_ count: Int, reply: @escaping () -> Void)
    func setPerDomainConnectionLimit(_ limit: Int, reply: @escaping () -> Void)
    func headCheck(url: String, reply: @escaping (Data?) -> Void)
}

/// Builds the Authorization header value for optional HTTP Basic credentials.
public enum HTTPAuth {
    public static func basicHeader(username: String?, password: String?) -> String? {
        guard let username, !username.isEmpty else { return nil }
        let raw = "\(username):\(password ?? "")"
        guard let data = raw.data(using: .utf8) else { return nil }
        return "Basic " + data.base64EncodedString()
    }
}

/// XPC protocol: download service → app (progress callbacks)
@objc public protocol BDMDownloaderClientProtocol {
    func progressUpdate(_ data: Data)
    func downloadCompleted(id: String, filePath: String)
    func downloadFailed(id: String, error: String)
}
