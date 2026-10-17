import Foundation

if CommandLine.arguments.count == 3 {
    do {
        let lock = try SingleInstance(fileURL: URL(fileURLWithPath: CommandLine.arguments[2]))
        withExtendedLifetime(lock) {
            if CommandLine.arguments[1] == "--hold" {
                print("locked")
                fflush(stdout)
                _ = readLine()
            }
        }
        exit(0)
    } catch SingleInstance.Failure.alreadyRunning { exit(2) }
    catch { exit(3) }
}

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let lockURL = directory.appendingPathComponent("instance.lock")

func child(_ mode: String = "--probe", path: URL? = nil) throws -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    process.arguments = [mode, (path ?? lockURL).path]
    return process
}

func probe(_ expected: Int32, path: URL? = nil) throws {
    let process = try child(path: path)
    try process.run()
    process.waitUntilExit()
    precondition(process.terminationStatus == expected,
                 "Expected status \(expected), got \(process.terminationStatus)")
}

// Different processes, not just different descriptors in the same process.
do {
    let lock = try SingleInstance(fileURL: lockURL)
    try withExtendedLifetime(lock) { try probe(2) }
}
try probe(0)

// An abruptly terminated owner must not leave a stale lock.
let owner = try child("--hold")
let output = Pipe()
let input = Pipe()
owner.standardOutput = output
owner.standardInput = input
try owner.run()
precondition(output.fileHandleForReading.availableData == Data("locked\n".utf8))
try probe(2)
owner.terminate()
owner.waitUntilExit()
try probe(0)

// A symlink must not redirect the application into locking another file.
let target = directory.appendingPathComponent("unrelated.txt")
try Data("keep".utf8).write(to: target)
let link = directory.appendingPathComponent("link.lock")
try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
try probe(3, path: link)
let preserved = try Data(contentsOf: target)
precondition(preserved == Data("keep".utf8))
try probe(3, path: directory.appendingPathComponent("missing/instance.lock"))
print("Single-instance regressions: OK (concurrent process, clean exit, terminated owner, symlink, unavailable path)")
