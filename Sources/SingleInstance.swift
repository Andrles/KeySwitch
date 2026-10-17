import Darwin
import Foundation

/// A kernel-owned lock is released even if the application crashes. Keep the
/// file in place: unlinking it would allow two processes to lock different inodes.
final class SingleInstance {
    enum Failure: Error {
        case alreadyRunning
        case unavailable(Int32)
    }

    private let descriptor: Int32

    init(fileURL: URL) throws {
        let descriptor = fileURL.path.withCString {
            open($0, O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else {
            let code = errno
            if code == EWOULDBLOCK { throw Failure.alreadyRunning }
            throw Failure.unavailable(code)
        }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_uid == getuid(),
              metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_nlink == 1 else {
            close(descriptor)
            throw Failure.unavailable(EACCES)
        }
        self.descriptor = descriptor
    }

    deinit { close(descriptor) }
}
