import XCTest
@testable import KeetaClient

final class CompressionTests: XCTestCase {
    func test_basicViceVersa() throws {
        let data = try XCTUnwrap("Some test data".data(using: .utf8))
        
        let compressed = compress(data)
        
        XCTAssertNotEqual(compressed, data)
        
        let decompressed = decompress(compressed)
                
        XCTAssertEqual(decompressed, data)
    }
}
