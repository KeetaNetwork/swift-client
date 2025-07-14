struct HistoryResponse: Decodable {
    let history: [HistoryContentResponse]
}

internal struct HistoryContentResponse: Decodable {
    let id: String
    let timestamp: String
    let voteStaple: VoteStapleContentResponse
    
    enum CodingKeys: String, CodingKey {
        case voteStaple
        case id = "$id"
        case timestamp = "$timestamp"
    }
}

internal struct VoteStapleContentResponse: Decodable {
    let binary: String
    
    enum CodingKeys: String, CodingKey {
        case binary = "$binary"
    }
}
