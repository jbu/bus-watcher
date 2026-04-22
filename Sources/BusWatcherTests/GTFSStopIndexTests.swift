import XCTest
@testable import BusWatcher

final class GTFSStopIndexTests: XCTestCase {
    private let csv = """
    stop_id,stop_code,stop_name,stop_lat,stop_lon,location_type,parent_station,platform_code
    43000320101,nwmaptwp,"York St",52.459450,-1.947204,,,
    43000320602,nwmapwdt,"St Marys Road",52.455677,-1.954242,,,
    43000202601,nwmajadp,"Old Repertory Theatre",52.476753,-1.898996,,,
    43003002502,,"Blue, Coat School",52.462130,-1.947300,,,
    """

    func test_parse_count() {
        let records = GTFSStopIndex.parse(csv)
        XCTAssertEqual(records.count, 4)
    }

    func test_parse_quotedCommaInName() {
        let records = GTFSStopIndex.parse(csv)
        XCTAssertEqual(records.last?.name, "Blue, Coat School")
    }

    func test_search_caseInsensitive() {
        let index = GTFSStopIndex(records: GTFSStopIndex.parse(csv))
        XCTAssertEqual(index.search(query: "YORK").map(\.id), ["43000320101"])
        XCTAssertEqual(index.search(query: "york").map(\.id), ["43000320101"])
    }

    func test_search_partialMatch() {
        let index = GTFSStopIndex(records: GTFSStopIndex.parse(csv))
        XCTAssertEqual(index.search(query: "mary").map(\.id), ["43000320602"])
    }

    func test_search_emptyQuery_returnsEmpty() {
        let index = GTFSStopIndex(records: GTFSStopIndex.parse(csv))
        XCTAssertEqual(index.search(query: "").count, 0)
        XCTAssertEqual(index.search(query: "   ").count, 0)
    }

    func test_search_limitRespected() {
        let many = (0..<100).map { StopRecord(id: "id\($0)", code: "c\($0)", name: "Common Name \($0)", lat: 0, lon: 0) }
        let index = GTFSStopIndex(records: many)
        XCTAssertEqual(index.search(query: "common", limit: 10).count, 10)
    }

    func test_stopById_found() {
        let index = GTFSStopIndex(records: GTFSStopIndex.parse(csv))
        XCTAssertEqual(index.stop(byId: "43000320602")?.name, "St Marys Road")
        XCTAssertNil(index.stop(byId: "does-not-exist"))
    }

    func test_parseRow_latLonCoerced() {
        let rec = GTFSStopIndex.parseRow(#"43000320101,abc,"Test",52.45,-1.94,,,"#)
        XCTAssertEqual(rec?.lat, 52.45)
        XCTAssertEqual(rec?.lon, -1.94)
    }
}
