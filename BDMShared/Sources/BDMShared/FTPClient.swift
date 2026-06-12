import Foundation
import Network

/// A directory entry returned by `FTPClient.list`.
public struct FTPEntry: Sendable, Identifiable, Hashable {
    public let name: String
    public let isDirectory: Bool
    public let size: Int64

    public var id: String { name }

    public init(name: String, isDirectory: Bool, size: Int64) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
    }
}

public enum FTPError: Error, LocalizedError {
    case connectionFailed(String)
    case unexpectedReply(Int, String)
    case loginFailed
    case dataConnectionFailed
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let why): return "FTP connection failed: \(why)"
        case .unexpectedReply(let code, let text): return "FTP error \(code): \(text)"
        case .loginFailed: return "FTP login failed"
        case .dataConnectionFailed: return "FTP data connection failed"
        case .cancelled: return "FTP transfer cancelled"
        }
    }
}

/// Minimal FTP client: passive mode, USER/PASS login, LIST, SIZE, CWD, and
/// RETR with REST resume. URLSession dropped FTP, so this speaks the protocol
/// directly over Network.framework.
public actor FTPClient {
    private let host: String
    private let port: UInt16
    private var control: NWConnection?
    private var buffer = Data()

    public init(host: String, port: UInt16 = 21) {
        self.host = host
        self.port = port
    }

    deinit {
        control?.cancel()
    }

    // MARK: - Session

    public func connect(username: String = "anonymous", password: String = "bdm@example.com") async throws {
        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 21,
            using: .tcp
        )
        try await Self.start(conn)
        control = conn

        let greeting = try await readReply()
        guard greeting.code == 220 else { throw FTPError.unexpectedReply(greeting.code, greeting.text) }

        let user = try await command("USER \(username)")
        if user.code == 331 {
            let pass = try await command("PASS \(password)")
            guard pass.code == 230 else { throw FTPError.loginFailed }
        } else if user.code != 230 {
            throw FTPError.loginFailed
        }

        _ = try await command("TYPE I") // binary mode
    }

    public func disconnect() {
        control?.cancel()
        control = nil
        buffer.removeAll()
    }

    // MARK: - Queries

    /// File size in bytes (also validates the path exists).
    public func size(of path: String) async throws -> Int64 {
        let reply = try await command("SIZE \(path)")
        guard reply.code == 213, let size = Int64(reply.text.trimmingCharacters(in: .whitespaces)) else {
            throw FTPError.unexpectedReply(reply.code, reply.text)
        }
        return size
    }

    /// Lists a directory (absolute path).
    public func list(_ path: String) async throws -> [FTPEntry] {
        let data = try await transfer(command: "LIST \(path)")
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return text
            .split(whereSeparator: \.isNewline)
            .compactMap(Self.parseListLine)
            .filter { $0.name != "." && $0.name != ".." }
            .sorted { ($0.isDirectory ? 0 : 1, $0.name.lowercased()) < ($1.isDirectory ? 0 : 1, $1.name.lowercased()) }
    }

    /// Downloads `path` starting at `offset`, feeding chunks to `sink`.
    /// The sink may throw (e.g. CancellationError) to abort the transfer.
    public func download(
        _ path: String,
        offset: Int64 = 0,
        sink: @Sendable (Data) async throws -> Void
    ) async throws {
        let data = try await openDataConnection()
        defer { data.cancel() }

        if offset > 0 {
            let rest = try await command("REST \(offset)")
            guard rest.code == 350 else { throw FTPError.unexpectedReply(rest.code, rest.text) }
        }

        let retr = try await command("RETR \(path)")
        guard retr.code == 150 || retr.code == 125 else {
            throw FTPError.unexpectedReply(retr.code, retr.text)
        }

        while true {
            try Task.checkCancellation()
            guard let chunk = try await Self.receiveChunk(data) else { break } // EOF
            try await sink(chunk)
        }

        let done = try await readReply()
        guard done.code == 226 || done.code == 250 else {
            throw FTPError.unexpectedReply(done.code, done.text)
        }
    }

    // MARK: - Data connections

    private func transfer(command cmd: String) async throws -> Data {
        let data = try await openDataConnection()
        defer { data.cancel() }

        let reply = try await command(cmd)
        guard reply.code == 150 || reply.code == 125 else {
            throw FTPError.unexpectedReply(reply.code, reply.text)
        }

        var collected = Data()
        while let chunk = try await Self.receiveChunk(data) {
            collected.append(chunk)
        }

        let done = try await readReply()
        guard done.code == 226 || done.code == 250 else {
            throw FTPError.unexpectedReply(done.code, done.text)
        }
        return collected
    }

    private func openDataConnection() async throws -> NWConnection {
        let pasv = try await command("PASV")
        guard pasv.code == 227 else { throw FTPError.unexpectedReply(pasv.code, pasv.text) }

        // "Entering Passive Mode (h1,h2,h3,h4,p1,p2)"
        let numbers = pasv.text
            .split(whereSeparator: { !"0123456789".contains($0) })
            .compactMap { Int($0) }
        guard numbers.count >= 6 else { throw FTPError.dataConnectionFailed }
        let parts = Array(numbers.suffix(6))
        let dataHost = "\(parts[0]).\(parts[1]).\(parts[2]).\(parts[3])"
        let dataPort = UInt16(parts[4] * 256 + parts[5])

        let conn = NWConnection(
            host: NWEndpoint.Host(dataHost),
            port: NWEndpoint.Port(rawValue: dataPort) ?? 20,
            using: .tcp
        )
        try await Self.start(conn)
        return conn
    }

    // MARK: - Control channel

    private func command(_ cmd: String) async throws -> (code: Int, text: String) {
        guard let control else { throw FTPError.connectionFailed("not connected") }
        try await Self.send(control, data: Data((cmd + "\r\n").utf8))
        return try await readReply()
    }

    /// Reads one (possibly multi-line) FTP reply.
    private func readReply() async throws -> (code: Int, text: String) {
        var lines: [String] = []
        var expectedCode: Int?

        while true {
            let line = try await readLine()
            guard line.count >= 3, let code = Int(line.prefix(3)) else { continue }

            if expectedCode == nil {
                if line.count > 3, line[line.index(line.startIndex, offsetBy: 3)] == "-" {
                    expectedCode = code // multi-line reply, wait for "NNN " terminator
                    lines.append(String(line.dropFirst(4)))
                    continue
                }
                return (code, String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces))
            }

            lines.append(String(line.dropFirst(min(4, line.count))))
            if code == expectedCode, line.count > 3,
               line[line.index(line.startIndex, offsetBy: 3)] == " " {
                return (code, lines.joined(separator: "\n").trimmingCharacters(in: .whitespaces))
            }
        }
    }

    private func readLine() async throws -> String {
        guard let control else { throw FTPError.connectionFailed("not connected") }
        while true {
            if let range = buffer.range(of: Data("\r\n".utf8)) {
                let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                return String(decoding: lineData, as: UTF8.self)
            }
            guard let chunk = try await Self.receiveChunk(control) else {
                throw FTPError.connectionFailed("control channel closed")
            }
            buffer.append(chunk)
        }
    }

    // MARK: - NWConnection plumbing

    private static func start(_ conn: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumed = ResumeOnce()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumed.run { continuation.resume() }
                case .failed(let error):
                    resumed.run { continuation.resume(throwing: FTPError.connectionFailed(error.localizedDescription)) }
                case .cancelled:
                    resumed.run { continuation.resume(throwing: FTPError.cancelled) }
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }
    }

    private static func send(_ conn: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: FTPError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Returns nil on clean EOF.
    private static func receiveChunk(_ conn: NWConnection) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: FTPError.connectionFailed(error.localizedDescription))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    // MARK: - LIST parsing

    /// Parses a unix-style LIST line:
    /// `-rw-r--r--   1 owner group     1234 Jan  1 12:00 file name.txt`
    static func parseListLine(_ line: Substring) -> FTPEntry? {
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 9, let first = fields.first?.first else { return nil }
        guard "d-l".contains(first) else { return nil }

        let size = Int64(fields[4]) ?? 0
        // Name = everything after the 8th field in the original line
        guard let nameStart = line.range(of: String(fields[7]))?.upperBound else { return nil }
        var name = String(line[nameStart...]).trimmingCharacters(in: .whitespaces)
        if first == "l", let arrow = name.range(of: " -> ") {
            name = String(name[..<arrow.lowerBound])
        }
        guard !name.isEmpty else { return nil }

        return FTPEntry(name: name, isDirectory: first == "d", size: size)
    }
}

/// Resumes a continuation at most once (NWConnection state handlers fire repeatedly).
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
