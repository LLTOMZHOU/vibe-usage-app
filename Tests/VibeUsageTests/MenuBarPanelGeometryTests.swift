import AppKit
import XCTest
@testable import VibeUsage

final class MenuBarPanelGeometryTests: XCTestCase {
    func testPanelTopUsesEachDisplaysUsableTopInsteadOfStatusWindowY() {
        let cases: [(button: NSRect, visible: NSRect)] = [
            (
                button: NSRect(x: 1047, y: 1112, width: 1, height: 30),
                visible: NSRect(x: 0, y: 0, width: 1865, height: 1050)
            ),
            (
                button: NSRect(x: -9, y: 1112, width: 1, height: 30),
                visible: NSRect(x: -1920, y: 0, width: 1920, height: 1080)
            ),
        ]

        for item in cases {
            let point = PopoverGeometry.topLeftPoint(
                buttonFrame: item.button,
                visibleFrame: item.visible,
                panelWidth: 520,
                horizontalInset: 8,
                topGap: 6
            )

            XCTAssertEqual(point.y, item.visible.maxY - 6)
        }
    }

    func testPanelRightAlignsToButtonAndClampsToDisplayEdges() {
        let rightAligned = PopoverGeometry.topLeftPoint(
            buttonFrame: NSRect(x: 1_300, y: 877, width: 24, height: 23),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_440, height: 877),
            panelWidth: 520,
            horizontalInset: 8,
            topGap: 6
        )
        XCTAssertEqual(rightAligned.x, 804)

        let leftClamped = PopoverGeometry.topLeftPoint(
            buttonFrame: NSRect(x: -1_910, y: 1_057, width: 24, height: 23),
            visibleFrame: NSRect(x: -1_920, y: 0, width: 1_920, height: 1_057),
            panelWidth: 520,
            horizontalInset: 8,
            topGap: 6
        )
        XCTAssertEqual(leftClamped.x, -1_912)
    }
}
