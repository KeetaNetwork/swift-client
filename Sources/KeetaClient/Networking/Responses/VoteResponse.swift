import Foundation

internal struct BlockVoteResponse: Decodable {
    let blockhash: String
    let votes: [VoteContentResponse]?
}

internal struct VoteResponse: Decodable {
    let vote: VoteContentResponse
}

internal struct VoteContentResponse: Decodable {
    let id: String
    let issuer: String
    let serial: String
    let blocks: [String]
    let validityFrom: String
    let validityTo: String
    let signature: String
    let binary: String
    
    enum CodingKeys: String, CodingKey {
        case issuer, serial, blocks, validityFrom, validityTo, signature
        case binary = "$binary"
        case id = "$uid"
    }
}
