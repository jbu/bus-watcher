import XCTest
@testable import BusWatcher

final class TfWMServiceTests: XCTestCase {

    override func setUp() async throws {
        MockURLProtocol.handler = nil
    }

    // MARK: - Nearby

    func test_nearbyStops_decodesMultiLineResponse() async {
        MockURLProtocol.handler = { request in
            let body = """
            {"StopPointsResponse":{"CentrePoint":{"lat":52.459,"lon":-1.947},"StopPoints":{"StopPoint":[
              {"Id":"43000320103","Lat":52.459,"Lon":-1.947,"CommonName":"York St","Distance":7.3,
               "NaptanId":"43000320103","StopType":"NaptanMarkedPoint",
               "Lines":{"Identifier":[{"Id":"3370","Name":"55"},{"Id":"5413","Name":"19"}]}}
            ]},"Total":1}}
            """
            return Self.respond(url: request, body: body)
        }
        let service = TfWMService(session: Self.session())
        let stops = await service.nearbyStops(lat: 52.459, lon: -1.947)
        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops.first?.id, "43000320103")
        XCTAssertEqual(stops.first?.lines.map(\.id), ["3370", "5413"])
        XCTAssertEqual(stops.first?.lines.map(\.name), ["55", "19"])
    }

    func test_nearbyStops_emptyResponse() async {
        MockURLProtocol.handler = { request in
            Self.respond(url: request, body: """
            {"StopPointsResponse":{"CentrePoint":{"lat":52.0,"lon":-1.0},"StopPoints":{"StopPoint":[]},"Total":0}}
            """)
        }
        let stops = await TfWMService(session: Self.session()).nearbyStops(lat: 52.0, lon: -1.0)
        XCTAssertEqual(stops, [])
    }

    // MARK: - Stop detail

    func test_fetchStopDetail_multiLine() async {
        MockURLProtocol.handler = { request in
            let body = """
            {"StopPoint":{"Id":"43000320101","CommonName":"York St","Lat":52.4594,"Lon":-1.9472,
              "NaptanId":"43000320101","StopType":"NaptanMarkedPoint",
              "Lines":{"Identifier":[
                {"Id":"3370","Name":"55"},
                {"Id":"1144","Name":"11A"},
                {"Id":"179","Name":"11A"}
              ]}}}
            """
            return Self.respond(url: request, body: body)
        }
        let detail = await TfWMService(session: Self.session()).fetchStopDetail(stopId: "43000320101")
        XCTAssertEqual(detail?.id, "43000320101")
        XCTAssertEqual(detail?.lines.count, 3)
        let groupedByName = Set(detail?.lines.map(\.name) ?? [])
        XCTAssertEqual(groupedByName, Set(["55", "11A"]))
    }

    func test_fetchStopDetail_singleLineAsDict() async {
        // The API sometimes returns Lines.Identifier as a dict (single item) instead of array.
        MockURLProtocol.handler = { request in
            let body = """
            {"StopPoint":{"Id":"x","CommonName":"Only","Lat":0,"Lon":0,"NaptanId":"x","StopType":"NaptanMarkedPoint",
              "Lines":{"Identifier":{"Id":"9","Name":"9"}}}}
            """
            return Self.respond(url: request, body: body)
        }
        let detail = await TfWMService(session: Self.session()).fetchStopDetail(stopId: "x")
        XCTAssertEqual(detail?.lines.map(\.id), ["9"])
    }

    func test_fetchStopDetail_noLines() async {
        MockURLProtocol.handler = { request in
            let body = """
            {"StopPoint":{"Id":"y","CommonName":"Empty","Lat":0,"Lon":0,"NaptanId":"y","StopType":"NaptanMarkedPoint"}}
            """
            return Self.respond(url: request, body: body)
        }
        let detail = await TfWMService(session: Self.session()).fetchStopDetail(stopId: "y")
        XCTAssertEqual(detail?.lines, [])
    }

    // MARK: - Arrivals dedup

    func test_fetchArrivals_prefersLiveOverScheduled() async {
        // One live + one scheduled for the same trip → one merged entry, live preferred.
        let future1 = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))
        let future2 = ISO8601DateFormatter().string(from: Date().addingTimeInterval(600))
        MockURLProtocol.handler = { request in
            let body = """
            {"ArrayOfPrediction":{"Prediction":[
              {"Id":"a","LineName":"11A","ScheduledArrival":"\(future1)"},
              {"Id":"b","LineName":"11A","ExpectedArrival":"\(future1)","ScheduledArrival":"\(future1)"},
              {"Id":"c","LineName":"11A","ScheduledArrival":"\(future2)"}
            ]}}
            """
            return Self.respond(url: request, body: body)
        }
        let stop = StopConfig(
            id: "t", lineIds: ["1144"], stopId: "43000320602",
            routeLabel: "11A", stopName: "Test",
            latitude: 0, longitude: 0, colorToken: .blue
        )
        let arrivals = await TfWMService(session: Self.session()).fetchArrivals(for: stop)
        XCTAssertEqual(arrivals.count, 2)
        XCTAssertTrue(arrivals[0].isLive, "First-sorted (soonest) should be the live one")
    }

    // MARK: - Helpers

    private static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func respond(url request: URLRequest, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
