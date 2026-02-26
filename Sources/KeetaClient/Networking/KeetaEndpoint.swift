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
    
    static func temporaryVotes(
        for blocks: [Block], quotes: [String: VoteQuote] = [:], from reps: [String: String]
    ) throws -> [Self] {
        try reps.map { pubKey, url in
            let body = try VoteRequest(blocks: blocks, quote: quotes[pubKey], votes: nil).toJSON()
            return .init(url: url + "/vote", method: .post, body: body)
        }
    }
    
    static func permanentVotes(for blocks: [Block], temporaryVotes: [Vote], from repBaseUrls: Set<String>) throws -> [Self] {
        let body = try VoteRequest(blocks: blocks, quote: nil, votes: temporaryVotes).toJSON()
        return repBaseUrls.map { .init(url: $0 + "/vote", method: .post, body: body) }
    }
    
    static func vote(for hash: String, side: LedgerSide, repBaseUrls: Set<String>) -> [Self] {
        repBaseUrls.map { .init(url: $0 + "/vote/\(hash)", method: .get, query: ["side": side.rawValue]) }
    }
    
    static func voteQuote(for blocks: [Block], repBaseUrls: Set<String>) throws -> [Self] {
        let data: JSON = ["blocks": try blocks.map { try $0.base64String() }]
        return repBaseUrls.map { .init(url: $0 + "/vote/quote", method: .post, body: data) }
    }
    
    static func pendingBlock(for account: Account, baseUrl: String) -> Self {
        .init(url: baseUrl + "/node/ledger/account/\(account.publicKeyString)/pending", method: .get)
    }
    
    static func pendingBlock(for account: Account, from repBaseUrls: Set<String>) -> [Self] {
        repBaseUrls.map { pendingBlock(for: account, baseUrl: $0) }
    }
    
    static func publish(voteStaple: VoteStaple, to repBaseUrls: Set<String>) -> [Self] {
        let body = ["votesAndBlocks": voteStaple.base64String()]
        return repBaseUrls.map { .init(url: $0 + "/node/publish", method: .post, body: body) }
    }
    
    static func representatives(baseUrl: String) -> Self {
        .init(url: baseUrl + "/node/ledger/representatives", method: .get)
    }
    
    static func certificates(for account: Account, baseUrl: String) -> Self {
        .init(url: baseUrl + "/node/ledger/account/\(account.publicKeyString)/certificates", method: .get)
    }
    
    static func certificate(for account: Account, hash: String, baseUrl: String) -> Self {
        .init(url: baseUrl + "/node/ledger/account/\(account.publicKeyString)/certificates/\(hash)", method: .get)
    }
    
    static func accountInfo(of account: Account, baseUrl: String) -> Self {
        .init(url: baseUrl + "/node/ledger/account/\(account.publicKeyString)", method: .get)
    }
    
    static func block(for hash: String, side: LedgerSide?, baseUrl: String) -> Self {
        let path = "/node/ledger/block/\(hash)"
        return .init(url: baseUrl + path, method: .get, query: side.map { ["side": $0.rawValue] } ?? [:])
    }
    
    static func block(for account: Account, idempotent: String, side: LedgerSide, baseUrl: String) -> Self {
        let path = "/node/ledger/account/\(account.publicKeyString)/idempotent/\(idempotent)"
        return .init(url: baseUrl + path, method: .get, query: ["side": side.rawValue])
    }
    
    static func permissionsReceived(for account: Account, filter: [Account] = [], baseUrl: String) -> Self {
        let path = "/node/ledger/account/\(account.publicKeyString)/acl/\(filter.map(\.publicKeyString).joined(separator: ","))"
        return .init(url: baseUrl + path, method: .get)
    }
    
    static func grantedPermissions(for account: Account, baseUrl: String) -> Self {
        let path = "/node/ledger/account/\(account.publicKeyString)/acl/granted"
        return .init(url: baseUrl + path, method: .get)
    }
    
    static func history(for account: Account, limit: Int, startBlocksHash: String?, baseUrl: String) -> Self {
        var path = "/node/ledger/account/\(account.publicKeyString)/history"
        
        if let startBlocksHash {
            path += "/start/\(startBlocksHash)"
        }
        
        return .init(url: baseUrl + path, method: .get, query: ["limit": "\(limit)"])
    }
}
