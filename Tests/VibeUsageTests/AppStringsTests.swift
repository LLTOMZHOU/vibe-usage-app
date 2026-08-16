import XCTest
@testable import VibeUsage

final class AppStringsTests: XCTestCase {
    func testUsesEnglishForEnglishSystemLanguage() {
        XCTAssertEqual(AppStrings.text("设置", "Settings", languageIdentifier: "en-US"), "Settings")
    }

    func testUsesChineseForChineseSystemLanguage() {
        XCTAssertEqual(AppStrings.text("设置", "Settings", languageIdentifier: "zh-Hans-CN"), "设置")
    }
}
