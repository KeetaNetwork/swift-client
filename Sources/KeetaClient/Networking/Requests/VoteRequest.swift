struct VoteRequest {
    let blocks: [Block]
    let quote: VoteQuote?
    let votes: [Vote]?

    func toJSON() throws -> JSON {
        var data: JSON = [
            "blocks": try blocks.map { try $0.base64String() }
        ]
        if let quote {
            data["quote"] = quote.base64String()
        }
        if let votes {
            data["votes"] = votes.map { $0.base64String() }
        }
        return data
    }
}
