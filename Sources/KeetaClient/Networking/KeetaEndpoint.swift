import Foundation

struct KeetaEndpoint: Endpoint {
    init(url: String, method: RequestMethod, header: [String : String]? = Self.defaultHeader, query: [String: String] = [:], body: JSON? = nil) {
        self.urlString = url
        self.method = method.value
        self.header = header
        self.query = query
        self.body = body
    }
    
    static let defaultHeader = ["content-type": "application/json"]

    let urlString: String
    let method: String
    let header: [String: String]?
    let query: [String: String]
    let body: JSON?

    var url: URL {
        get throws {
            guard let url = URL(string: urlString) else {
                throw RequestError<Error>.invalidURL
            }
            return url
        }
    }
    
    static func publish(blocks: [Block], networkAlias: NetworkAlias, aidBaseUrl: String) throws -> Self {
        let body = try SendBlocksRequest(blocks: blocks, networkAlias: networkAlias).toJSON()
        return .init(url: aidBaseUrl + "/publish", method: .post, body: body)
    }
    
    static func votes(for blocks: [Block], temporaryVotes: [Vote]? = nil, from repBaseUrls: Set<String>) throws -> [Self] {
        let body = try VoteRequest(blocks: blocks, votes: temporaryVotes).toJSON()
        return repBaseUrls.map { .init(url: $0 + "/vote", method: .post, body: body) }
    }
    
    static func vote(for hash: String, side: LedgerSide, repBaseUrls: Set<String>) -> [Self] {
        repBaseUrls.map { .init(url: $0 + "/vote/\(hash)", method: .get, query: ["side": side.rawValue]) }
    }
    
    static func pendingBlock(for account: Account, baseUrl: String) -> Self {
        .init(url: baseUrl + "/node/ledger/account/\(account.publicKeyString)/pending", method: .get)
    }
    
    static func publish(voteStaple: VoteStaple, to repBaseUrls: Set<String>) -> [Self] {
        let body = ["votesAndBlocks": voteStaple.base64String()]
        return repBaseUrls.map { .init(url: $0 + "/node/publish", method: .post, body: body) }
    }
    
    static func accountInfo(of account: Account, baseUrl: String) -> Self {
        .init(url: baseUrl + "/node/ledger/account/\(account.publicKeyString)", method: .get)
    }
    
    static func history(for account: Account, limit: Int, startBlockHash: String?, baseUrl: String) -> Self {
        var path = "/node/ledger/account/\(account.publicKeyString)/history"
        
        if let startBlockHash {
            path += "/start/\(startBlockHash)"
        }
        
        return .init(url: baseUrl + path, method: .get, query: ["limit": "\(limit)"])
    }
}
