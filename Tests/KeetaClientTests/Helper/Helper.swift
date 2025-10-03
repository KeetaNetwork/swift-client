import XCTest
@testable import KeetaClient

extension XCTestCase {
    func printHexArray(using bytes: [UInt8]) {
        let arrayString = bytes.map { "0x" + Data([$0]).hexString.uppercased() }.joined(separator: ", ")
        print(arrayString)
    }
    
    func captureError<T: Error>(
        _ expected: T? = nil,
        failure: String,
        callLine: UInt = #line,
        file: StaticString = #file,
        execute: @escaping () throws -> Void
    ) {
        do {
            try execute()
            
            XCTFail(failure)
        } catch let error as T {
            if let expected = expected {
                // not ideal but don't want to enforce the implementation of Equatable
                XCTAssertEqual(error.localizedDescription, expected.localizedDescription, file: file, line: callLine)
            }
        } catch let error {
            if expected != nil {
                XCTFail("Invalid error: \(error)", file: file, line: callLine)
            }
        }
    }
}

extension Block {
    
    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]
        return formatter
    }()
    
    func prettyPrint() throws {
        print("** Block **")
        print("Hash:")
        print(hash)
        print("Base64 Content:")
        print(try base64String())
        print("Signaure:")
        print(signature.toHexString())
        print("------------\n")
    }
}
