import XCTest
import SwiftUI
@testable import BusWatcher

final class StopColorTests: XCTestCase {
    func test_codable_roundTrip_allCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in StopColor.allCases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(StopColor.self, from: data)
            XCTAssertEqual(original, decoded)
        }
    }

    func test_color_nonNilForAllCases() {
        for c in StopColor.allCases {
            // Compiler guarantees non-nil for Color; this just exercises every branch.
            _ = c.color
        }
    }

    func test_rawValue_isLowercaseStringMatchingCase() {
        XCTAssertEqual(StopColor.blue.rawValue, "blue")
        XCTAssertEqual(StopColor.teal.rawValue, "teal")
        XCTAssertEqual(StopColor.pink.rawValue, "pink")
    }
}
