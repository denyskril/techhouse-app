import XCTest
@testable import TechHouseApp

final class TechHouseAppTests: XCTestCase {
    func testThreadFiltering() async {
        let api = PreviewXenForoAPI()
        let sut = ThreadListViewModel(api: api)
        await sut.load()
        sut.searchText = "#1"
        XCTAssertTrue(sut.filteredThreads.allSatisfy { $0.title.contains("#1") })
    }
}
