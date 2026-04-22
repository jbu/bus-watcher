import XCTest
@testable import BusWatcher

final class ArrivalDecodingTests: XCTestCase {
    private let fixture = """
    {
      "ArrayOfPrediction": {
        "Prediction": [
          {
            "Id": "1",
            "LineName": "11A",
            "DestinationName": "Shirley Road",
            "ExpectedArrival": "2026-04-22T10:43:00Z",
            "ScheduledArrival": "2026-04-22T10:42:00Z"
          },
          {
            "Id": "2",
            "LineName": "11A",
            "ScheduledArrival": "2026-04-22T10:50:00Z"
          },
          {
            "Id": "3",
            "LineName": "35",
            "DestinationName": "Ridgemount Drive",
            "ScheduledArrival": "2026-04-22T10:55:00Z"
          }
        ]
      }
    }
    """

    func test_decodes_threePredictions() throws {
        let data = fixture.data(using: .utf8)!
        let response = try JSONDecoder().decode(ArrivalResponse.self, from: data)
        XCTAssertEqual(response.arrayOfPrediction.prediction.count, 3)
    }

    func test_isLive_distinction() throws {
        let data = fixture.data(using: .utf8)!
        let preds = try JSONDecoder().decode(ArrivalResponse.self, from: data).arrayOfPrediction.prediction
        XCTAssertTrue(preds[0].isLive)
        XCTAssertFalse(preds[1].isLive)
        XCTAssertFalse(preds[2].isLive)
    }

    func test_missingDestinationName_isNil() throws {
        let data = fixture.data(using: .utf8)!
        let preds = try JSONDecoder().decode(ArrivalResponse.self, from: data).arrayOfPrediction.prediction
        XCTAssertNil(preds[1].destinationName)
        XCTAssertEqual(preds[0].destinationName, "Shirley Road")
    }

    func test_displayArrival_picksExpectedThenScheduled() throws {
        let data = fixture.data(using: .utf8)!
        let preds = try JSONDecoder().decode(ArrivalResponse.self, from: data).arrayOfPrediction.prediction
        XCTAssertEqual(preds[0].displayArrival, "2026-04-22T10:43:00Z")
        XCTAssertEqual(preds[1].displayArrival, "2026-04-22T10:50:00Z")
    }
}
