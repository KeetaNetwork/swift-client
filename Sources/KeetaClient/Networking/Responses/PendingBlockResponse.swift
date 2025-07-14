import Foundation

struct PendingBlockResponse: Decodable {
    let account: String
    let block: BlockContentResponse?
}

internal struct BlockContentResponse: Decodable {
    let hash: String
    let signer: String
    let signature: String
    
    enum CodingKeys: String, CodingKey {
        case signer, signature
        case hash = "$hash"
    }
}
