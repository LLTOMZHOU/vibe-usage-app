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
                LabeledContent(AppStrings.text("数据源", "Data source")) {
                    Label(AppStrings.text("本机日志", "Local logs"), systemImage: "internaldrive.fill")
                        .foregroundStyle(.green)
                }
                Text(AppStrings.text("仪表盘默认只读取本机支持工具的使用记录，不需要账户，也不会上传数据。", "The dashboard reads usage records from supported local tools by default. No account is required and nothing is uploaded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(AppStrings.text("本机仪表盘", "Local dashboard"))
            }

            // Optional cloud account section
            Section {
                LabeledContent(AppStrings.text("账户", "Account")) {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(appState.isConfigured ? apiKeyDisplay : AppStrings.text("未连接", "Not connected"))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Color(white: 0.5))

                            Button(isRelinking
                                   ? AppStrings.text("等待确认…", "Waiting for confirmation…")
                                   : (appState.isConfigured ? AppStrings.text("重新连接", "Reconnect") : AppStrings.text("连接 VibeCafe", "Connect VibeCafe"))) {
                                relinkTask = Task { await relink() }
                            }
                            .font(.caption)
                            .disabled(isRelinking)

                            if isRelinking {
                                Button(AppStrings.text("取消", "Cancel")) {
                                    cancelRelink()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        if let relinkUserCode {
                            Text(AppStrings.text("验证码: \(relinkUserCode)", "Code: \(relinkUserCode)"))
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
                    LabeledContent(AppStrings.text("同步状态", "Sync status")) {
                        HStack(spacing: 4) {
                            switch appState.syncStatus {
                            case .idle:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(appState.remoteSyncEnabled ? AppStrings.text("已启用", "Enabled") : AppStrings.text("已连接，未启用", "Connected, disabled"))
                            case .syncing:
                                ProgressView()
                                    .controlSize(.small)
                                Text(AppStrings.text("同步中...", "Syncing..."))
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(AppStrings.text("同步成功", "Synced"))
                            case .error(let msg):
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(msg)
                                    .lineLimit(1)
                            }
                        }
                        .font(.caption)
                    }

                    Button(AppStrings.text("立即同步到 VibeCafe", "Sync to VibeCafe now")) {
                        Task { await appState.triggerSync() }
                    }
                    .disabled(!appState.remoteSyncEnabled || appState.syncStatus == .syncing)
                }

                if let lastSync = appState.lastSyncTime {
                    LabeledContent(AppStrings.text("上次同步", "Last sync")) {
                        Text(Formatters.formatRelativeTime(lastSync))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(AppStrings.text("可选云同步", "Optional cloud sync"))
            } footer: {
                Text(AppStrings.text("连接账户本身不会上传本机记录。只有连接后再明确开启“允许同步到 VibeCafe”才会上传。", "Connecting an account does not upload local records. Uploading starts only after you explicitly turn on Allow sync to VibeCafe."))
                    .font(.caption)
            }

            Section {
                Toggle(AppStrings.text("允许同步到 VibeCafe", "Allow sync to VibeCafe"), isOn: Binding(
                    get: { appState.remoteSyncEnabled },
                    set: { newValue in
                        Task { await appState.setRemoteSyncEnabled(newValue) }
                    }
                ))
                .tint(.green)
                .disabled(!appState.isConfigured)

                Toggle(AppStrings.text("上传项目名称", "Upload project names"), isOn: Binding(
                    get: { appState.uploadProjectNames },
                    set: { appState.uploadProjectNames = $0 }
                ))
                .tint(.green)

                Toggle(AppStrings.text("上传会话统计", "Upload session statistics"), isOn: Binding(
                    get: { appState.uploadSessionMetadata },
                    set: { appState.uploadSessionMetadata = $0 }
                ))
                .tint(.green)

                Toggle(AppStrings.text("显示在公开排行榜", "Show on the public leaderboard"), isOn: Binding(
                    get: { appState.showInPublicLeaderboard },
                    set: { newValue in
                        Task { await appState.setShowInPublicLeaderboard(newValue) }
                    }
                ))
                .tint(.orange)
            } header: {
                Text(AppStrings.text("隐私", "Privacy"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppStrings.text("同步默认关闭。开启后只上传半小时聚合的 Token 数；项目名称和会话时间、时长、消息数均需另行开启。设备使用随机别名，不上传电脑名称。", "Sync is off by default. When enabled, it uploads only half-hour token totals; project names and session timing, duration, and message counts each require separate opt-in. Your device uses a random alias, not its computer name."))
                    Text(AppStrings.text("公开排行榜默认关闭。每次上传前，本应用都会向 VibeCafe 验证服务器已采用这里的选择；无法确认时同步会安全取消。只有你明确开启后才会公开展示。", "The public leaderboard is off by default. Before every upload, the app verifies that VibeCafe accepted this choice; if it cannot verify, syncing safely stops. You appear publicly only after explicit opt-in."))
                    if appState.isConfigured {
                        Button(AppStrings.text("打开 VibeCafe 用量设置", "Open VibeCafe usage settings")) {
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
                Toggle(AppStrings.text("显示 Codex 订阅配额", "Show Codex subscription limits"), isOn: Binding(
                    get: { appState.codexRateLimitEnabled },
                    set: { newValue in
                        Task { await appState.setCodexRateLimitEnabled(newValue) }
                    }
                ))
                .tint(.green)
                Text(AppStrings.text("开启后会读取 Codex 的本机登录凭据，并联系 OpenAI 用量接口。", "When enabled, this reads local Codex sign-in credentials and contacts the OpenAI usage endpoint."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(isOn: Binding(
                    get: { appState.claudeRateLimitEnabled },
                    set: { newValue in
                        Task { await appState.setClaudeRateLimitEnabled(newValue) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppStrings.text("显示 Claude 订阅配额", "Show Claude subscription limits"))
                        // Only worth explaining when the numbers come from the
                        // Claude Code copy bundled inside Claude Desktop, which
                        // the user never installed themselves.
                        if appState.claudeUsesDesktopBundledCLI {
                            Text(AppStrings.text("数据来源：Claude Desktop", "Source: Claude Desktop"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.green)
                Text(AppStrings.text("开启后会启动本机 Claude Code 读取配额；该进程会使用自己的登录凭据。", "When enabled, this starts local Claude Code to read limits; that process uses its own sign-in credentials."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(AppStrings.text("订阅配额", "Subscription limits"))
            }

            // Menu bar display
            Section {
                Toggle(AppStrings.text("菜单栏显示费用", "Show cost in menu bar"), isOn: Binding(
                    get: { appState.showCostInMenuBar },
                    set: { appState.showCostInMenuBar = $0 }
                ))
                .tint(.green)
                Toggle(AppStrings.text("菜单栏显示 Token", "Show tokens in menu bar"), isOn: Binding(
                    get: { appState.showTokensInMenuBar },
                    set: { appState.showTokensInMenuBar = $0 }
                ))
                .tint(.green)
            } header: {
                Text(AppStrings.text("菜单栏", "Menu bar"))
            } footer: {
                Text(AppStrings.text("在菜单栏图标旁显示费用和 Token 用量", "Show cost and token usage beside the menu-bar icon."))
                    .font(.caption)
            }

            // Auto-start + general
            Section {
                Toggle(AppStrings.text("开机自启动", "Launch at login"), isOn: $autoStartEnabled)
                    .tint(.green)
                    .onChange(of: autoStartEnabled) { _, newValue in
                        setAutoStart(newValue)
                    }

                Toggle(AppStrings.text("在 Dock 中显示", "Show in Dock"), isOn: Binding(
                    get: { appState.showInDock },
                    set: { appState.showInDock = $0 }
                ))
                .tint(.green)
            } header: {
                Text(AppStrings.text("通用", "General"))
            } footer: {
                Text(AppStrings.text("关闭设置窗口后生效", "Takes effect after closing Settings."))
                    .font(.caption)
            }

            // About & Updates
            Section {
                LabeledContent(AppStrings.text("版本", "Version")) {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppConfig.version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(AppStrings.text("查看发布版本", "Check for updates")) {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            } header: {
                Text(AppStrings.text("关于", "About"))
            }

            if appState.isConfigured {
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Text(AppStrings.text("断开 VibeCafe", "Disconnect VibeCafe"))
                    }
                    .confirmationDialog(AppStrings.text("确定要断开 VibeCafe 吗？", "Disconnect VibeCafe?"), isPresented: $showingResetConfirmation) {
                        Button(AppStrings.text("断开", "Disconnect"), role: .destructive) {
                            disconnectCloud()
                        }
                        Button(AppStrings.text("取消", "Cancel"), role: .cancel) {}
                    } message: {
                        Text(AppStrings.text("这将删除 API Key 并停止云同步。本机仪表盘和本机数据不会受影响。", "This removes the API key and stops cloud sync. Your local dashboard and local data are unaffected."))
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
            apiKeyDisplay = AppStrings.text("未配置", "Not configured")
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
            relinkError = AppStrings.text("无法连接服务端：\(error.localizedDescription)", "Could not connect to the service: \(error.localizedDescription)")
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
                relinkError = AppStrings.text("服务端返回未知错误：\(res.error ?? "unknown")", "The service returned an unknown error: \(res.error ?? "unknown")")
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
        apiKeyDisplay = AppStrings.text("未连接", "Not connected")
    }
}
