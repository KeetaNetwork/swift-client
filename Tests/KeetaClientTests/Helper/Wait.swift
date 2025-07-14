import XCTest

extension XCTestCase {
    func wait(
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line,
        error: (() -> String)? = nil,
        unitl: @escaping () -> Bool
    ) async throws {
        let started = Date()
        
        while !unitl() {
            if started.addingTimeInterval(timeout) < Date() {
                let message = error?() ?? ""
                XCTFail("Timed out waiting\n\(message)", file: file, line: line)
                throw NSError(domain: "Timed out waiting\n\(message)", code: 0)
            }
            
            if #available(iOS 16.0, *) {
                try await Task.sleep(for: .milliseconds(100))
            } else {
                try await Task.sleep(nanoseconds: 100 * 1_000_000)
            }
        }
    }
}
