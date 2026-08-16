import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject var updaterViewModel: UpdaterViewModel

    @State private var apiKeyDisplay: String = ""
    @State private var autoStartEnabled: Bool = false
    @State private var showingResetConfirmation = false
    @State private var isRelinking = false
    @State private var relinkUserCode: String?
    @State private var relinkError: String?
    @State private var relinkTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                LabeledContent("数据源") {
                    Label("本机日志", systemImage: "internaldrive.fill")
                        .foregroundStyle(.green)
                }
                Text("仪表盘默认只读取本机支持工具的使用记录，不需要账户，也不会上传数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("本机仪表盘")
            }

            // Optional cloud account section
            Section {
                LabeledContent("账户") {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(appState.isConfigured ? apiKeyDisplay : "未连接")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Color(white: 0.5))

                            Button(isRelinking ? "等待确认…" : (appState.isConfigured ? "重新连接" : "连接 VibeCafe")) {
                                relinkTask = Task { await relink() }
                            }
                            .font(.caption)
                            .disabled(isRelinking)

                            if isRelinking {
                                Button("取消") {
                                    cancelRelink()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        if let relinkUserCode {
                            Text("验证码: \(relinkUserCode)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        if let relinkError {
                            Text(relinkError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                    }
                }

                if appState.isConfigured {
                    LabeledContent("同步状态") {
                        HStack(spacing: 4) {
                            switch appState.syncStatus {
                            case .idle:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(appState.remoteSyncEnabled ? "已启用" : "已连接，未启用")
                            case .syncing:
                                ProgressView()
                                    .controlSize(.small)
                                Text("同步中...")
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("同步成功")
                            case .error(let msg):
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(msg)
                                    .lineLimit(1)
                            }
                        }
                        .font(.caption)
                    }

                    Button("立即同步到 VibeCafe") {
                        Task { await appState.triggerSync() }
                    }
                    .disabled(!appState.remoteSyncEnabled || appState.syncStatus == .syncing)
                }

                if let lastSync = appState.lastSyncTime {
                    LabeledContent("上次同步") {
                        Text(Formatters.formatRelativeTime(lastSync))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("可选云同步")
            } footer: {
                Text("连接账户本身不会上传本机记录。只有连接后再明确开启“允许同步到 VibeCafe”才会上传。")
                    .font(.caption)
            }

            Section {
                Toggle("允许同步到 VibeCafe", isOn: Binding(
                    get: { appState.remoteSyncEnabled },
                    set: { newValue in
                        Task { await appState.setRemoteSyncEnabled(newValue) }
                    }
                ))
                .tint(.green)
                .disabled(!appState.isConfigured)

                Toggle("上传项目名称", isOn: Binding(
                    get: { appState.uploadProjectNames },
                    set: { appState.uploadProjectNames = $0 }
                ))
                .tint(.green)

                Toggle("上传会话统计", isOn: Binding(
                    get: { appState.uploadSessionMetadata },
                    set: { appState.uploadSessionMetadata = $0 }
                ))
                .tint(.green)

                Toggle("显示在公开排行榜", isOn: Binding(
                    get: { appState.showInPublicLeaderboard },
                    set: { newValue in
                        Task { await appState.setShowInPublicLeaderboard(newValue) }
                    }
                ))
                .tint(.orange)
            } header: {
                Text("隐私")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("同步默认关闭。开启后只上传半小时聚合的 Token 数；项目名称和会话时间、时长、消息数均需另行开启。设备使用随机别名，不上传电脑名称。")
                    Text("公开排行榜默认关闭。每次上传前，本应用都会向 VibeCafe 验证服务器已采用这里的选择；无法确认时同步会安全取消。只有你明确开启后才会公开展示。")
                    if appState.isConfigured {
                        Button("打开 VibeCafe 用量设置") {
                            if let url = URL(string: "\(AppConfig.defaultApiUrl)/usage/setup") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
                .font(.caption)
            }

            // Subscription quota monitoring
            Section {
                Toggle("显示 Codex 订阅配额", isOn: Binding(
                    get: { appState.codexRateLimitEnabled },
                    set: { newValue in
                        Task { await appState.setCodexRateLimitEnabled(newValue) }
                    }
                ))
                .tint(.green)
                Text("开启后会读取 Codex 的本机登录凭据，并联系 OpenAI 用量接口。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(isOn: Binding(
                    get: { appState.claudeRateLimitEnabled },
                    set: { newValue in
                        Task { await appState.setClaudeRateLimitEnabled(newValue) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示 Claude 订阅配额")
                        // Only worth explaining when the numbers come from the
                        // Claude Code copy bundled inside Claude Desktop, which
                        // the user never installed themselves.
                        if appState.claudeUsesDesktopBundledCLI {
                            Text("数据来源：Claude Desktop")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.green)
                Text("开启后会启动本机 Claude Code 读取配额；该进程会使用自己的登录凭据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("订阅配额")
            }

            // Menu bar display
            Section {
                Toggle("菜单栏显示费用", isOn: Binding(
                    get: { appState.showCostInMenuBar },
                    set: { appState.showCostInMenuBar = $0 }
                ))
                .tint(.green)
                Toggle("菜单栏显示 Token", isOn: Binding(
                    get: { appState.showTokensInMenuBar },
                    set: { appState.showTokensInMenuBar = $0 }
                ))
                .tint(.green)
            } header: {
                Text("菜单栏")
            } footer: {
                Text("在菜单栏图标旁显示费用和 Token 用量")
                    .font(.caption)
            }

            // Auto-start + general
            Section {
                Toggle("开机自启动", isOn: $autoStartEnabled)
                    .tint(.green)
                    .onChange(of: autoStartEnabled) { _, newValue in
                        setAutoStart(newValue)
                    }

                Toggle("在 Dock 中显示", isOn: Binding(
                    get: { appState.showInDock },
                    set: { appState.showInDock = $0 }
                ))
                .tint(.green)
            } header: {
                Text("通用")
            } footer: {
                Text("关闭设置窗口后生效")
                    .font(.caption)
            }

            // About & Updates
            Section {
                LabeledContent("版本") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppConfig.version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("查看发布版本") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            } header: {
                Text("关于")
            }

            if appState.isConfigured {
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Text("断开 VibeCafe")
                    }
                    .confirmationDialog("确定要断开 VibeCafe 吗？", isPresented: $showingResetConfirmation) {
                        Button("断开", role: .destructive) {
                            disconnectCloud()
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("这将删除 API Key 并停止云同步。本机仪表盘和本机数据不会受影响。")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 680)
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - Private

    private func loadSettings() {
        if let config = ConfigManager.load(), let key = config.apiKey {
            if key.count > 12 {
                apiKeyDisplay = "\(key.prefix(8))...\(key.suffix(4))"
            } else {
                apiKeyDisplay = key
            }
        } else {
            apiKeyDisplay = "未配置"
        }

        autoStartEnabled = SMAppService.mainApp.status == .enabled
    }

    private func setAutoStart(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set auto-start: \(error)")
        }
    }

    private func relink() async {
        relinkError = nil
        relinkUserCode = nil
        isRelinking = true
        defer { isRelinking = false }

        let baseURL = AppConfig.defaultApiUrl
        let hostname = AppConfig.deviceAlias
        let device: DeviceCodeResponse
        do {
            device = try await requestDeviceCode(baseURL: baseURL, clientName: "Vibe Usage.app", hostname: hostname)
        } catch {
            relinkError = "无法连接服务端：\(error.localizedDescription)"
            return
        }

        relinkUserCode = device.userCode
        if let url = URL(string: device.verificationUriComplete) {
            NSWorkspace.shared.open(url)
        }

        let intervalNs = UInt64(max(device.interval, 1)) * 1_000_000_000
        let deadline = Date().addingTimeInterval(TimeInterval(device.expiresIn))

        while Date() < deadline {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: intervalNs)
            if Task.isCancelled { return }
            let res: DevicePollResponse
            do {
                res = try await pollDeviceCode(baseURL: baseURL, deviceCode: device.deviceCode)
            } catch {
                continue
            }
            if let apiKey = res.apiKey {
                appState.configure(apiKey: apiKey, apiUrl: AppConfig.validatedServiceURL(res.apiUrl ?? baseURL))
                relinkUserCode = nil
                loadSettings()
                return
            }
            switch res.error {
            case "authorization_pending", nil:
                continue
            case "access_denied":
                relinkError = DeviceFlowError.denied.localizedDescription
                relinkUserCode = nil
                return
            case "expired_token":
                relinkError = DeviceFlowError.expired.localizedDescription
                relinkUserCode = nil
                return
            default:
                relinkError = "服务端返回未知错误：\(res.error ?? "unknown")"
                relinkUserCode = nil
                return
            }
        }
        relinkError = DeviceFlowError.expired.localizedDescription
        relinkUserCode = nil
    }

    /// Abort an in-flight re-link so the user can start over immediately rather
    /// than waiting out the 15-minute timeout. The cancelled task returns at its
    /// next checkpoint; its `defer` clears `isRelinking`.
    private func cancelRelink() {
        relinkTask?.cancel()
        relinkTask = nil
        relinkUserCode = nil
        relinkError = nil
        isRelinking = false
    }

    private func disconnectCloud() {
        appState.disconnectCloud()
        apiKeyDisplay = "未连接"
    }
}
