import SwiftUI

/// Main popover container — full dashboard view
struct PopoverView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        dashboardView
        .frame(width: 520)
        .background(Color(white: 0.04))
    }

    // MARK: - Dashboard

    private var dashboardView: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .background(Color(white: 0.16))

            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if appState.isInitialDataLoad || (!appState.hasLoadedUsageData && appState.buckets.isEmpty) {
                        rateLimitSection
                        FilterTagsView()
                        loadingDashboardView
                    } else if !appState.hasAnyData {
                        rateLimitSection
                        emptyStateView
                    } else {
                        dashboardContent
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 560)

            Divider()
                .background(Color(white: 0.16))

            // Footer
            footerBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }

    private var dashboardContent: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                // Rate-limit row gets its own block separated from the usage
                // dashboard by a divider so quota and consumption stats stay distinct.
                rateLimitSection
                FilterTagsView()
                    .zIndex(10)
                SummaryCardsView()
                BarChartView()
                DistributionChartsView()
            }
            .opacity(appState.isRefreshingData ? 0.72 : 1)
            .animation(.easeInOut(duration: 0.2), value: appState.isRefreshingData)

            if appState.isRefreshingData {
                refreshOverlay
                    .transition(.opacity)
                    .zIndex(30)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isRefreshingData)
    }

    @ViewBuilder
    private var rateLimitSection: some View {
        if appState.codexRateLimitEnabled || appState.claudeRateLimitEnabled {
            // zIndex must beat FilterTagsView's (10): the quota hover tooltip
            // overflows below the card, and the filter row would otherwise
            // paint over it.
            RateLimitCardView()
                .zIndex(20)
            Divider()
                .background(Color(white: 0.16))
                .padding(.vertical, 2)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Vibe Usage")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                if AppConfig.isDev {
                    Text("DEBUG")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(3)
                }

                // Keep the persistent update affordance beside the app title,
                // where it remains visible without competing with footer actions.
                if updaterViewModel.availableUpdate != nil {
                    Button {
                        updaterViewModel.checkForUpdates()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                            Text("发现更新")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.15))
                        .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .help("发现新版本，点击更新")
                }
            }

            Spacer()

            // Settings — NSWindow directly (SwiftUI scenes don't work in LSUIElement MenuBarExtra)
            Button {
                SettingsWindowController.shared.show(appState: appState, updaterViewModel: updaterViewModel)
            } label: {
                Text("设置")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.12))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.18), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 0) {
            // Local dashboard status
            HStack(spacing: 6) {
                if appState.isLoadingData {
                    ProgressView()
                        .controlSize(.mini)
                } else if appState.localDataError != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                }

                Text(appState.localDataError ?? (appState.isLoadingData ? "正在读取本机数据..." : "本机数据 · 未上传"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.38))
                    .lineLimit(1)
            }

            Spacer()

            // Refresh button
            Button {
                Task {
                    async let local: Void = appState.fetchUsageData()
                    async let limits: Void = appState.refreshAllRateLimits()
                    _ = await (local, limits)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("更新数据")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color(white: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoadingData)

            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                    Text("关闭")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color(white: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
        }
    }

    // MARK: - States

    private var loadingDashboardView: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                SkeletonSummaryCards()
                SkeletonBlock(height: 238)
                SkeletonDistributionGrid()
            }
            .redacted(reason: .placeholder)
            .opacity(0.78)

            refreshOverlay
                .padding(.top, 90)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var refreshOverlay: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("加载中")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.66))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
        .allowsHitTesting(false)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(Color(white: 0.3))
            Text(appState.runtimeAvailable ? "暂无本机数据" : "需要 Node.js 或 Bun")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(white: 0.5))
            Text(appState.runtimeAvailable
                 ? "使用受支持的 AI 编程工具后，点击更新数据即可在本机查看"
                 : "安装 Node.js 20+ 或 Bun 后即可读取本机使用记录；无需登录")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.38))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

private struct SkeletonSummaryCards: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonBlock(height: 70)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
    }
}

private struct SkeletonDistributionGrid: View {
    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonBlock(height: 190)
            }
        }
    }
}

private struct SkeletonBlock: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(white: 0.09))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.16), lineWidth: 1))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}
