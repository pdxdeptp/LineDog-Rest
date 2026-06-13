import Foundation

enum InterventionRequestKind: String, Equatable {
    case countdown
    case bell
    case cancel
}

struct InterventionRequestContract: Equatable {
    let schemaVersion: Int
    let id: String
    let kind: InterventionRequestKind
    let minutes: Int?
    let title: String
    let requestedAt: Date
    let expiresAt: Date?

    var countdownEndDate: Date? {
        guard kind == .countdown, let minutes else { return nil }
        return requestedAt.addingTimeInterval(TimeInterval(minutes * 60))
    }

    func isExpired(at now: Date) -> Bool {
        guard let expiresAt else { return false }
        return now > expiresAt
    }

    func isCountdownPastDue(at now: Date) -> Bool {
        guard let end = countdownEndDate else { return false }
        return now >= end
    }
}

enum InterventionRequestContractError: Error, Equatable {
    case fileNotFound
    case readFailed
    case invalidJSON
    case missingField(String)
    case invalidKind(String)
    case invalidSchemaVersion(Int)
    case invalidMinutes
    case invalidDate(String)
}

struct InterventionRequestContractReader {
    let fileURL: URL

    static var defaultHermesPendingFileURL: URL {
        HermesRuntimePaths().interventionRequestFileURL
    }

    init(fileURL: URL = InterventionRequestContractReader.defaultHermesPendingFileURL) {
        self.fileURL = fileURL
    }

    func read() throws -> InterventionRequestContract {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw InterventionRequestContractError.fileNotFound
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw InterventionRequestContractError.readFailed
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InterventionRequestContractError.invalidJSON
        }

        guard let schemaVersion = root["schemaVersion"] as? Int else {
            throw InterventionRequestContractError.missingField("schemaVersion")
        }
        guard schemaVersion == 1 else {
            throw InterventionRequestContractError.invalidSchemaVersion(schemaVersion)
        }
        guard let id = root["id"] as? String, !id.isEmpty else {
            throw InterventionRequestContractError.missingField("id")
        }
        guard let kindRaw = root["kind"] as? String,
              let kind = InterventionRequestKind(rawValue: kindRaw)
        else {
            throw InterventionRequestContractError.invalidKind((root["kind"] as? String) ?? "")
        }
        guard let title = root["title"] as? String, !title.isEmpty else {
            throw InterventionRequestContractError.missingField("title")
        }
        guard let requestedRaw = root["requestedAt"] as? String,
              let requestedAt = Self.parseISO8601(requestedRaw)
        else {
            throw InterventionRequestContractError.missingField("requestedAt")
        }

        var minutes: Int?
        if kind == .countdown {
            guard let m = root["minutes"] as? Int, m > 0 else {
                if root["minutes"] == nil {
                    throw InterventionRequestContractError.missingField("minutes")
                }
                throw InterventionRequestContractError.invalidMinutes
            }
            minutes = m
        }

        var expiresAt: Date?
        if let expiresRaw = root["expiresAt"] as? String {
            guard let parsed = Self.parseISO8601(expiresRaw) else {
                throw InterventionRequestContractError.invalidDate(expiresRaw)
            }
            expiresAt = parsed
        }

        return InterventionRequestContract(
            schemaVersion: schemaVersion,
            id: id,
            kind: kind,
            minutes: minutes,
            title: title,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    private static func parseISO8601(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: raw) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}
