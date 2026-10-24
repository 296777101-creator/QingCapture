import Foundation
import Darwin
public final class SingleInstanceLock {
    private var descriptor: Int32 = -1
    public init() {}
    public func acquire(at url: URL) -> Bool {
        if descriptor >= 0 { return true }
        do { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) } catch { return false }
        let fd = Darwin.open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return false }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { Darwin.close(fd); return false }
        descriptor = fd; return true
    }
    public func release() {
        if descriptor >= 0 { flock(descriptor, LOCK_UN); Darwin.close(descriptor); descriptor = -1 }
    }
    deinit { release() }
}
