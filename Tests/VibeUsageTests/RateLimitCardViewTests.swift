import Testing
@testable import VibeUsage

@MainActor
struct RateLimitCardViewTests {
    private func snapshot(
        provider: ProviderRateLimit.Provider,
        status: ProviderRateLimit.Status
    ) -> ProviderRateLimit {
        ProviderRateLimit(provider: provider, status: status)
    }

    @Test
    func enabledEmptyClaudeRemainsVisibleBesideAvailableCodex() {
        let visible = RateLimitCardView.visibleProviders(
            codex: snapshot(provider: .codex, status: .ok),
            claude: snapshot(provider: .claudeCode, status: .noData),
            codexEnabled: true,
            claudeEnabled: true,
            codexRefreshing: false,
            claudeRefreshing: false
        )

        #expect(visible == [.codex, .claudeCode])
    }

    @Test
    func allIdleEmptyProvidersUseTheNoticeBar() {
        let visible = RateLimitCardView.visibleProviders(
            codex: snapshot(provider: .codex, status: .noData),
            claude: snapshot(provider: .claudeCode, status: .noData),
            codexEnabled: true,
            claudeEnabled: true,
            codexRefreshing: false,
            claudeRefreshing: false
        )

        #expect(visible.isEmpty)
    }

    @Test
    func disabledProviderStaysHidden() {
        let visible = RateLimitCardView.visibleProviders(
            codex: snapshot(provider: .codex, status: .ok),
            claude: snapshot(provider: .claudeCode, status: .ok),
            codexEnabled: false,
            claudeEnabled: true,
            codexRefreshing: false,
            claudeRefreshing: false
        )

        #expect(visible == [.claudeCode])
    }

    @Test
    func refreshingProviderKeepsBothEnabledCardsVisible() {
        let visible = RateLimitCardView.visibleProviders(
            codex: snapshot(provider: .codex, status: .noData),
            claude: snapshot(provider: .claudeCode, status: .noData),
            codexEnabled: true,
            claudeEnabled: true,
            codexRefreshing: false,
            claudeRefreshing: true
        )

        #expect(visible == [.codex, .claudeCode])
    }
}
