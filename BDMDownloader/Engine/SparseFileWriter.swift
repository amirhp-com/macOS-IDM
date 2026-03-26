import Foundation

/// Thread-safe file writer using pwrite() for direct byte-offset writes.
/// Pre-allocates a sparse file and allows concurrent writes from multiple threads.
actor SparseFileWriter {
    private let fileDescriptor: Int32
    private let filePath: String
    let totalBytes: Int64

    init(path: String, totalBytes: Int64) throws {
        self.filePath = path
        self.totalBytes = totalBytes

        // Create parent directory if needed
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Open (create if needed) with read-write
        let fd = open(path, O_RDWR | O_CREAT, 0o644)
        guard fd >= 0 else {
            throw SparseFileError.cannotOpenFile(path, errno)
        }

        // Pre-allocate to the full size (sparse on APFS)
        if ftruncate(fd, off_t(totalBytes)) != 0 {
            close(fd)
            throw SparseFileError.cannotAllocate(totalBytes, errno)
        }

        self.fileDescriptor = fd
    }

    /// Write data at an exact byte offset. Safe to call from multiple tasks concurrently.
    func write(_ data: Data, at offset: Int64) throws {
        try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            let written = pwrite(fileDescriptor, baseAddress, buffer.count, off_t(offset))
            if written < 0 {
                throw SparseFileError.writeFailed(offset, errno)
            }
            if written != buffer.count {
                throw SparseFileError.partialWrite(expected: buffer.count, actual: written)
            }
        }
    }

    /// Rename from .bdm-partial to final name (zero-copy assembly).
    func finalize(as finalPath: String) throws {
        Darwin.close(fileDescriptor)
        if rename(filePath, finalPath) != 0 {
            throw SparseFileError.renameFailed(filePath, finalPath, errno)
        }
    }

    /// Close without finalizing (e.g., on cancel).
    func closeFile() {
        Darwin.close(fileDescriptor)
    }
}

enum SparseFileError: Error, LocalizedError {
    case cannotOpenFile(String, Int32)
    case cannotAllocate(Int64, Int32)
    case writeFailed(Int64, Int32)
    case partialWrite(expected: Int, actual: Int)
    case renameFailed(String, String, Int32)

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path, let err):
            return "Cannot open file at \(path): errno \(err)"
        case .cannotAllocate(let size, let err):
            return "Cannot allocate \(size) bytes: errno \(err)"
        case .writeFailed(let offset, let err):
            return "Write failed at offset \(offset): errno \(err)"
        case .partialWrite(let expected, let actual):
            return "Partial write: expected \(expected), wrote \(actual)"
        case .renameFailed(let from, let to, let err):
            return "Rename \(from) → \(to) failed: errno \(err)"
        }
    }
}
