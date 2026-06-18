import AppKit

/// LRU 缓存：解码后的 GIF 帧与原始 Data，避免长跑内存无界增长。
enum GIFFrameCache {
    static let maxGIFEntries = 5

    private static var frameStorage: [URL: [(NSImage, TimeInterval)]] = [:]
    private static var frameOrder: [URL] = []

    private static var dataStorage: [URL: Data] = [:]
    private static var dataOrder: [URL] = []

    static func decodedFrames(for url: URL) -> [(NSImage, TimeInterval)]? {
        frameStorage[url]
    }

    static func storeDecodedFrames(_ frames: [(NSImage, TimeInterval)], for url: URL) {
        if frameStorage[url] != nil {
            frameOrder.removeAll { $0 == url }
        }
        frameStorage[url] = frames
        frameOrder.append(url)
        evictFrameEntriesIfNeeded()
    }

    static func gifData(for url: URL) -> Data? {
        dataStorage[url]
    }

    static func storeGIFData(_ data: Data, for url: URL) {
        if dataStorage[url] != nil {
            dataOrder.removeAll { $0 == url }
        }
        dataStorage[url] = data
        dataOrder.append(url)
        evictDataEntriesIfNeeded()
    }

    private static func evictFrameEntriesIfNeeded() {
        while frameOrder.count > maxGIFEntries {
            let evicted = frameOrder.removeFirst()
            frameStorage.removeValue(forKey: evicted)
        }
    }

    private static func evictDataEntriesIfNeeded() {
        while dataOrder.count > maxGIFEntries {
            let evicted = dataOrder.removeFirst()
            dataStorage.removeValue(forKey: evicted)
        }
    }

    // MARK: - Tests (@testable)

    internal static func testing_reset() {
        frameStorage.removeAll()
        frameOrder.removeAll()
        dataStorage.removeAll()
        dataOrder.removeAll()
    }

    internal static var testing_frameEntryCount: Int { frameStorage.count }
}
