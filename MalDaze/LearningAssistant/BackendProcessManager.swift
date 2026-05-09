import Foundation
import Network

extension Notification.Name {
    /// 后端进程已就绪（端口可接受连接）时发送；ViewModel 监听后再首次 fetch。
    static let backendDidBecomeReady = Notification.Name("BackendProcessManagerDidBecomeReady")
}

/// Option B 后端进程管理：桌宠启动时探测 8765 端口。
/// - 端口已占用（手动 uvicorn）→ 不接管，退出时也不 kill。
/// - 端口空闲 → spawn .venv/bin/uvicorn，退出时 kill。
@MainActor
final class BackendProcessManager {
    static let shared = BackendProcessManager()

    private var process: Process?
    private var ownsProcess = false
    /// ViewModel 可在订阅通知前检查此标志，避免错过通知。
    private(set) var isReady = false

    private let port: UInt16 = 8765

    func start() {
        Task {
            if await isPortBound() {
                ownsProcess = false
                markReady()
            } else {
                spawnBackend()
                await waitUntilReady()
            }
        }
    }

    private func markReady() {
        isReady = true
        NotificationCenter.default.post(name: .backendDidBecomeReady, object: nil)
    }

    /// 轮询端口，最多等 30 秒；无论成败都发通知，失败时 ViewModel 会显示离线。
    private func waitUntilReady() async {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if await isPortBound() {
                markReady()
                return
            }
        }
        markReady()
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
        // 层 1：生产期 — bundle 内置（打包时将 assistant_backend 放入 Resources）
        if let resourceURL = Bundle.main.resourceURL {
            let candidate = resourceURL.appendingPathComponent("assistant_backend")
            if isBackendDir(candidate) { return candidate }
        }

        // 层 2：开发期 — 从 DerivedData/<Name>-<hash>/info.plist 读取 WorkspacePath
        // 结构：.../DerivedData/X/Build/Products/Config/App.app → 向上 4 层找 info.plist
        var searchDir = Bundle.main.bundleURL
        for _ in 0..<5 {
            searchDir = searchDir.deletingLastPathComponent()
            let infoPlist = searchDir.appendingPathComponent("info.plist")
            if let plist = NSDictionary(contentsOf: infoPlist),
               let workspacePath = plist["WorkspacePath"] as? String {
                let projectRoot = URL(fileURLWithPath: workspacePath).deletingLastPathComponent()
                let candidate = projectRoot.appendingPathComponent("assistant_backend")
                if isBackendDir(candidate) { return candidate }
            }
        }

        // 层 3：兜底 — .app 同级目录向上查找 6 层（app 在项目目录附近时生效）
        var dir = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("assistant_backend")
            if isBackendDir(candidate) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    private func isBackendDir(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("src/main.py").path)
    }
}
