import Foundation

struct BlockResponse: Decodable {
    let blockhash: String?
    let block: BlockContentResponse
}

struct PendingBlockResponse: Decodable {
    let account: String
    let block: BlockContentResponse?
}

internal enum BlockContentResponse: Decodable {
    case v1(BlockContentResponseV1)
    case v2(BlockContentResponseV2)
    
    var hash: String {
        switch self {
        case .v1(let v1): v1.hash
        case .v2(let v2): v2.hash
        }
    }
    
    var idempotent: String? {
        switch self {
        case .v1(let v1): v1.idempotent
        case .v2(let v2): v2.idempotent
        }
    }
    
    var binary: String {
        switch self {
        case .v1(let v1): v1.binary
        case .v2(let v2): v2.binary
        }
    }
    
    init(from decoder: Swift.Decoder) throws {
        // Try latest version first
        if let v2 = try? BlockContentResponseV2(from: decoder) {
            self = .v2(v2)
            return
        }
        
        if let v1 = try? BlockContentResponseV1(from: decoder) {
            self = .v1(v1)
            return
        }
        
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Data did not match BlockContentResponseV1 or BlockContentResponseV2"
            )
        )
    }
}

internal struct BlockContentResponseV2: Decodable {
    let hash: String
    let idempotent: String?
    let signer: String
    let signatures: [String]
    let binary: String
    
    enum CodingKeys: String, CodingKey {
        case signer, signatures, idempotent
        case hash = "$hash"
        case binary = "$binary"
    }
}

internal struct BlockContentResponseV1: Decodable {
    let hash: String
    let idempotent: String?
    let signer: String
    let signature: String
    let binary: String
    
    enum CodingKeys: String, CodingKey {
        case signer, signature, idempotent
        case hash = "$hash"
        case binary = "$binary"
    }
}
