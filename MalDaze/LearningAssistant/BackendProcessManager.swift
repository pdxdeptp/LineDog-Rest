import Foundation
import Network

/// Option B 后端进程管理：桌宠启动时探测 8765 端口。
/// - 端口已占用（手动 uvicorn）→ 不接管，退出时也不 kill。
/// - 端口空闲 → spawn .venv/bin/uvicorn，退出时 kill。
@MainActor
final class BackendProcessManager {
    static let shared = BackendProcessManager()

    private var process: Process?
    private var ownsProcess = false

    private let port: UInt16 = 8765

    func start() {
        Task {
            if await isPortBound() {
                ownsProcess = false
            } else {
                spawnBackend()
            }
        }
    }

    func stop() {
        guard ownsProcess, let p = process, p.isRunning else { return }
        p.terminate()
        process = nil
        ownsProcess = false
    }

    // MARK: - Port Detection

    private func isPortBound() async -> Bool {
        await withCheckedContinuation { continuation in
            let conn = NWConnection(
                host: "127.0.0.1",
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            var resumed = false

            conn.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    resumed = true
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            conn.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                guard !resumed else { return }
                resumed = true
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Spawn

    private func spawnBackend() {
        guard let backendDir = findBackendDir() else { return }
        let uvicorn = backendDir.appendingPathComponent(".venv/bin/uvicorn")
        guard FileManager.default.fileExists(atPath: uvicorn.path) else { return }

        let p = Process()
        p.executableURL      = uvicorn
        p.arguments          = ["src.main:app", "--host", "127.0.0.1", "--port", "\(port)"]
        p.currentDirectoryURL = backendDir

        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.process     = nil
                self?.ownsProcess = false
            }
        }

        do {
            try p.run()
            process     = p
            ownsProcess = true
        } catch {
            // 启动失败时静默：UI 侧会通过 AssistantOfflineError 提示用户
        }
    }

    // MARK: - Backend Path Resolution

    private func findBackendDir() -> URL? {
        // 生产期：bundle 内置（打包时将 assistant_backend 放入 Resources）
        if let resourceURL = Bundle.main.resourceURL {
            let candidate = resourceURL.appendingPathComponent("assistant_backend")
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("src/main.py").path) {
                return candidate
            }
        }

        // 兜底：.app 同级目录向上查找
        var dir = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("assistant_backend")
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("src/main.py").path) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }
}
