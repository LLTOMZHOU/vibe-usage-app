import Foundation
import Testing
@testable import VibeUsage

struct FormattersTests {
    @Test
    func relativeTimeUsesTimelineDateInsteadOfWallClock() {
        let producedAt = Date(timeIntervalSince1970: 1_000)
        let timelineDate = producedAt.addingTimeInterval(6 * 60)

        #expect(
            Formatters.formatRelativeTime(producedAt, relativeTo: timelineDate, languageIdentifier: "zh-Hans")
                == "6 分钟前"
        )

        #expect(
            Formatters.formatRelativeTime(producedAt, relativeTo: timelineDate, languageIdentifier: "en-US")
                == "6 min ago"
        )
    }
}
