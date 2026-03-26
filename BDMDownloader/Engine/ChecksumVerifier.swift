import Foundation
import CryptoKit
import BDMShared

/// Streaming checksum verifier for completed files.
struct ChecksumVerifier: Sendable {

    /// Verify a file's checksum against an expected hash.
    func verify(filePath: String, algorithm: ChecksumAlgorithm, expected: String) async throws -> Bool {
        let computed = try await computeHash(filePath: filePath, algorithm: algorithm)
        return computed.lowercased() == expected.lowercased()
    }

    /// Compute the hash of a file using streaming reads (low memory).
    func computeHash(filePath: String, algorithm: ChecksumAlgorithm) async throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: URL(filePath: filePath))
        defer { try? fileHandle.close() }

        let bufferSize = 1024 * 1024 // 1 MB chunks

        switch algorithm {
        case .sha256:
            var hasher = SHA256()
            while let chunk = try fileHandle.read(upToCount: bufferSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return SHA256.Digest.hexString(hasher.finalize())

        case .sha512:
            var hasher = SHA512()
            while let chunk = try fileHandle.read(upToCount: bufferSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return SHA512.Digest.hexString(hasher.finalize())

        case .md5:
            var hasher = Insecure.MD5()
            while let chunk = try fileHandle.read(upToCount: bufferSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return Insecure.MD5.Digest.hexString(hasher.finalize())
        }
    }
}

private extension HashDigest {
    static func hexString(_ digest: Self) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Conform all digest types to a common protocol for the hex helper
private protocol HashDigest: Sequence where Element == UInt8 {}
extension SHA256.Digest: HashDigest {}
extension SHA512.Digest: HashDigest {}
extension Insecure.MD5.Digest: HashDigest {}
