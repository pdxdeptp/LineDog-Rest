import Foundation
import Darwin

extension Notification.Name {
    /// 后端进程已就绪（端口可接受连接）时发送；ViewModel 监听后再首次 fetch。
    static let backendDidBecomeReady = Notification.Name("BackendProcessManagerDidBecomeReady")
    /// 后端启动失败、超时或已退出；ViewModel 可提示离线并允许用户重试。
    static let backendDidBecomeUnavailable = Notification.Name("BackendProcessManagerDidBecomeUnavailable")
}

@MainActor
protocol BackendProcessControlling: AnyObject {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var currentDirectoryURL: URL? { get set }
    var environment: [String: String]? { get set }
    var isRunning: Bool { get }

    func run() throws
    func terminate()
    func setTerminationHandler(_ handler: @escaping @MainActor @Sendable (BackendProcessControlling) -> Void)
}

extension Process: BackendProcessControlling {
    func setTerminationHandler(_ handler: @escaping @MainActor @Sendable (BackendProcessControlling) -> Void) {
        terminationHandler = { process in
            Task { @MainActor in
                handler(process)
            }
        }
    }
}

@MainActor
protocol AppBackendLifecycleManaging: AnyObject {
    var isReady: Bool { get }
    var isStarting: Bool { get }

    func startIfNeeded()
    func stop()
}

/// Option B 后端进程管理：桌宠启动时探测 8765 端口。
/// - 端口已占用（手动 uvicorn）→ 不接管，退出时也不 kill。
/// - 端口空闲 → spawn .venv/bin/uvicorn，退出时 kill。
@MainActor
final class BackendProcessManager: AppBackendLifecycleManaging {
    static let shared = BackendProcessManager()

    private var process: BackendProcessControlling?
    private var ownsProcess = false
    private var terminatingOwnedProcess: BackendProcessControlling?
    /// ViewModel 可在订阅通知前检查此标志，避免错过通知。
    private(set) var isReady = false
    private(set) var isStarting = false
    private var startupTask: Task<Void, Never>?
    private var startupGeneration = 0

    private let port: UInt16 = 8765
    private let backendDirectoryProvider: () -> URL?
    private let processFactory: () -> BackendProcessControlling
    private let parentProcessIdentifierProvider: () -> Int32
    private let portBoundProbe: (() async -> Bool)?
    private let readinessTimeout: TimeInterval
    private let readinessPollNanoseconds: UInt64

    init(
        backendDirectoryProvider: (() -> URL?)? = nil,
        processFactory: @escaping () -> BackendProcessControlling = { Process() },
        parentProcessIdentifierProvider: @escaping () -> Int32 = { getpid() },
        portBoundProbe: (() async -> Bool)? = nil,
        readinessTimeout: TimeInterval = 30,
        readinessPollNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.backendDirectoryProvider = backendDirectoryProvider ?? { nil }
        self.processFactory = processFactory
        self.parentProcessIdentifierProvider = parentProcessIdentifierProvider
        self.portBoundProbe = portBoundProbe
        self.readinessTimeout = readinessTimeout
        self.readinessPollNanoseconds = readinessPollNanoseconds
    }

    func startIfNeeded() {
        guard !isReady, !isStarting else { return }
        isStarting = true
        startupGeneration += 1
        let generation = startupGeneration
        startupTask?.cancel()
        startupTask = Task {
            if await isPortBound() {
                guard isCurrentStartupRequest(generation) else { return }
                if terminatingOwnedProcess != nil {
                    await waitForTerminatingOwnedProcessThenContinueStartup(generation: generation)
                    return
                }
                ownsProcess = false
                markReady()
            } else {
                guard isCurrentStartupRequest(generation) else { return }
                await spawnBackendAndWaitUntilReady(generation: generation)
            }
        }
    }

    private func isCurrentStartupRequest(_ generation: Int) -> Bool {
        !Task.isCancelled && startupGeneration == generation && isStarting
    }

    private func markReady() {
        startupTask = nil
        isReady = true
        isStarting = false
        NotificationCenter.default.post(name: .backendDidBecomeReady, object: nil)
    }

    private func markUnavailable() {
        startupTask = nil
        isReady = false
        isStarting = false
        NotificationCenter.default.post(name: .backendDidBecomeUnavailable, object: nil)
    }

    private func spawnBackendAndWaitUntilReady(generation: Int) async {
        guard spawnBackend() else {
            guard isCurrentStartupRequest(generation) else { return }
            markUnavailable()
            return
        }
        guard isCurrentStartupRequest(generation) else { return }
        await waitUntilReady(generation: generation)
    }

    private func waitForTerminatingOwnedProcessThenContinueStartup(generation: Int) async {
        let deadline = Date().addingTimeInterval(readinessTimeout)
        while terminatingOwnedProcess != nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: readinessPollNanoseconds)
            guard isCurrentStartupRequest(generation) else { return }
        }
        guard isCurrentStartupRequest(generation) else { return }
        guard terminatingOwnedProcess == nil else {
            markUnavailable()
            return
        }

        if await isPortBound() {
            guard isCurrentStartupRequest(generation) else { return }
            ownsProcess = false
            markReady()
        } else {
            guard isCurrentStartupRequest(generation) else { return }
            await spawnBackendAndWaitUntilReady(generation: generation)
        }
    }

    /// 轮询端口，最多等 30 秒；超时不伪装为 ready，交给 ViewModel 显示离线。
    private func waitUntilReady(generation: Int) async {
        let deadline = Date().addingTimeInterval(readinessTimeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: readinessPollNanoseconds)
            guard isCurrentStartupRequest(generation) else { return }
            if await isPortBound() {
                guard isCurrentStartupRequest(generation) else { return }
                markReady()
                return
            }
        }
        guard isCurrentStartupRequest(generation) else { return }
        markUnavailable()
    }

    func stop() {
        startupGeneration += 1
        startupTask?.cancel()
        startupTask = nil
        isStarting = false
        isReady = false
        guard ownsProcess, let p = process, p.isRunning else { return }
        terminatingOwnedProcess = p
        process = nil
        ownsProcess = false
        p.terminate()
    }

    // MARK: - Port Detection

    private func isPortBound() async -> Bool {
        if let portBoundProbe {
            return await portBoundProbe()
        }

        let port = port
        return await Task.detached(priority: .utility) {
            Self.isLocalhostPortBound(port: port)
        }.value
    }

    private nonisolated static func isLocalhostPortBound(port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else { return false }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let connectResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if connectResult == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        guard poll(&descriptor, 1, 500) > 0 else { return false }

        var socketError: Int32 = 0
        var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLength) == 0 else {
            return false
        }
        return socketError == 0
    }

    // MARK: - Spawn

    func spawnBackendForTesting() {
        _ = spawnBackend()
    }

    private func spawnBackend() -> Bool {
        if ownsProcess, let process, process.isRunning {
            return true
        }

        guard let backendDir = backendDirectoryProvider() ?? findBackendDir() else { return false }
        let uvicorn = backendDir.appendingPathComponent(".venv/bin/uvicorn")
        guard FileManager.default.fileExists(atPath: uvicorn.path) else { return false }

        let p = processFactory()
        p.executableURL      = uvicorn
        p.arguments          = ["src.main:app", "--host", "127.0.0.1", "--port", "\(port)"]
        p.currentDirectoryURL = backendDir
        var environment = ProcessInfo.processInfo.environment
        environment["MALDAZE_PARENT_PID"] = "\(parentProcessIdentifierProvider())"
        p.environment = environment

        p.setTerminationHandler { [weak self] terminatedProcess in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let terminatingProcess = self.terminatingOwnedProcess,
                   terminatingProcess === terminatedProcess {
                    self.terminatingOwnedProcess = nil
                    return
                }
                guard let currentProcess = self.process,
                      currentProcess === terminatedProcess else {
                    return
                }
                self.process     = nil
                self.ownsProcess = false
                self.markUnavailable()
            }
        }

        do {
            try p.run()
            process     = p
            ownsProcess = true
            return true
        } catch {
            return false
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
