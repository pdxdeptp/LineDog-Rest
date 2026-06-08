import Foundation

/// 已消费 intervention 记录目录：`~/.hermes/data/maldaze/consumed/{id}.json`
struct InterventionRequestAckStore {
    let consumedDirectoryURL: URL

    static var defaultConsumedDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/data/maldaze/consumed", isDirectory: true)
    }

    init(consumedDirectoryURL: URL = InterventionRequestAckStore.defaultConsumedDirectoryURL) {
        self.consumedDirectoryURL = consumedDirectoryURL
    }

    func hasConsumed(id: String) -> Bool {
        FileManager.default.fileExists(atPath: consumedFileURL(for: id).path)
    }

    func markConsumed(pendingFileURL: URL, contract: InterventionRequestContract) throws {
        try FileManager.default.createDirectory(
            at: consumedDirectoryURL,
            withIntermediateDirectories: true
        )
        let dest = consumedFileURL(for: contract.id)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        if FileManager.default.fileExists(atPath: pendingFileURL.path) {
            try FileManager.default.copyItem(at: pendingFileURL, to: dest)
            try FileManager.default.removeItem(at: pendingFileURL)
        } else {
            let payload = try JSONEncoder().encode(ConsumedInterventionRecord(from: contract))
            try payload.write(to: dest)
        }
    }

    private func consumedFileURL(for id: String) -> URL {
        consumedDirectoryURL.appendingPathComponent("\(id).json")
    }
}

private struct ConsumedInterventionRecord: Encodable {
    let id: String
    let kind: String
    let consumedAt: String

    init(from contract: InterventionRequestContract) {
        id = contract.id
        kind = contract.kind.rawValue
        consumedAt = ISO8601DateFormatter().string(from: Date())
    }
}
