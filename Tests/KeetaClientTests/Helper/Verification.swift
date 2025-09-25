import Foundation
@testable import KeetaClient
import XCTest

struct ExpectedBlockResult {
    let hash: String
    let signature: Block.Signature
    let version: Block.Version
    let created: Date
    let network: NetworkID
    let signerPubKey: String
    let account: String?
    let previous: String
    let isOpening: Bool
    
    init(hash: String, signature: String, version: Block.Version, created: String, network: NetworkID, signerPubKey: String, account: String? = nil, previous: String, isOpening: Bool) throws {
        guard let created = Block.dateFormatter.date(from: created) else {
            throw NSError(domain: "Invalid date string: \(created)", code: 0)
        }
        self.init(hash: hash, signature: try signature.toBytes(), version: version, created: created, network: network, signerPubKey: signerPubKey, account: account, previous: previous, isOpening: isOpening)
    }
    
    init(hash: String, signature: [UInt8], version: Block.Version, created: Date, network: NetworkID, signerPubKey: String, account: String? = nil, previous: String, isOpening: Bool) {
        self.hash = hash.uppercased()
        self.signature = .single(signature)
        self.version = version
        self.created = created
        self.network = network
        self.signerPubKey = signerPubKey.lowercased()
        self.account = account?.lowercased()
        self.previous = previous.lowercased()
        self.isOpening = isOpening
    }
}

extension Block {
    func compare(
        with expected: ExpectedBlockResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(hash, expected.hash, "Hash Mismatch", file: file, line: line)
        XCTAssertEqual(signature, expected.signature, "Signature Mismatch", file: file, line: line)
        XCTAssertEqual(rawData.previous, expected.previous, "Previous Mismatch", file: file, line: line)
        XCTAssertEqual(rawData.version, expected.version, "Version Mismatch", file: file, line: line)
        XCTAssertEqual(rawData.network, expected.network, "Network Mismatch", file: file, line: line)
        XCTAssertEqual(rawData.signer.publicKeyString, expected.signerPubKey, "Signer Mismatch", file: file, line: line)
        XCTAssertEqual(rawData.account.publicKeyString, expected.account ?? expected.signerPubKey, "Account Mismatch", file: file, line: line)
        XCTAssertEqual(rawData.created, expected.created, "Created Mismatch", file: file, line: line)
        XCTAssertEqual(opening, expected.isOpening, "Opening Mismatch", file: file, line: line)
    }
}

