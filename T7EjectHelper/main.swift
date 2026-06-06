import Foundation

let startedAt = Date()
let result = T7EjectResult.idleNotConnected(startedAt: startedAt, endedAt: Date())

do {
    print(try result.stdoutJSONString())
} catch {
    fputs("T7EjectHelper failed to encode result: \(error)\n", stderr)
    exit(1)
}
