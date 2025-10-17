import Foundation
import BigInt

public enum KeetaApiError: Error {
    case invalidBalanceValue(_ value: String)
    case invalidSupplyValue(_ value: String)
    case clientRepresentativeNotFound(_ address: String)
    case noVotes(errors: [Error])
    case missingAtLeastOneRep
    case feesRequiredButFeeBuilderMissing
    case blockAccountMismatch
    case blockHashMismatch
    case noPendingBlock(errors: [Error])
    case notPublished
}

public final class KeetaApi: HTTPClient {

    public var preferredRep: ClientRepresentative
    public var reps: [ClientRepresentative]
    public let networkId: NetworkID
    public let baseToken: Account
    
    private let decoder: Decoder = JSONDecoder()

    public convenience init(network: NetworkAlias) throws {
        try self.init(config: .create(for: network))
    }
    
    public convenience init(config: NetworkConfig) throws {
        try self.init(reps: config.reps, networkId: config.networkID, baseToken: config.baseToken)
    }
    
    public init(
        reps: [ClientRepresentative],
        networkId: NetworkID,
        baseToken: Account,
        preferredRep: ClientRepresentative? = nil
    ) throws {
        if reps.isEmpty { throw KeetaApiError.missingAtLeastOneRep }
        
        self.reps = reps
        self.preferredRep = preferredRep ?? reps.preferred ?? reps[0]
        self.networkId = networkId
        self.baseToken = baseToken
    }
    
    public func voteQuotes(for blocks: [Block]) async throws -> [VoteQuote] {
        let requests = try KeetaEndpoint.voteQuote(for: blocks, repBaseUrls: Set(reps.map(\.apiUrl)))
        let responses: [VoteQuoteResponse] = try await TaskGroup.load(requests) { try await self.sendRequest(to: $0) }
        return try responses.map { try VoteQuote.create(from: $0.quote.binary) }
    }
    
    public enum VoteType {
        case temporary(quotes: [VoteQuote]? = nil)
        case permanent(temporaryVotes: [Vote])
        
        var isPermanent: Bool {
            if case .permanent = self { true } else { false }
        }
    }
    
    @available(*, deprecated, message: "Use votes(for blocks: [Block], type: VoteType) method instead.")
    public func votes(for blocks: [Block], temporaryVotes: [Vote]? = nil) async throws -> [Vote] {
        let type: VoteType = if let temporaryVotes {
            .permanent(temporaryVotes: temporaryVotes)
        } else {
            .temporary(quotes: nil)
        }
        return try await votes(for: blocks, type: type)
    }
    
    public func votes(for blocks: [Block], type: VoteType) async throws -> [Vote] {
        let requests: [Endpoint]
        let repsInfo = Dictionary(uniqueKeysWithValues: reps.map({ ($0.address, $0.apiUrl) }))
        
        switch type {
        case .temporary(let quotes):
            let quotesInfo = Dictionary(uniqueKeysWithValues: quotes?.map({ ($0.issuer.publicKeyString, $0) }) ?? [])
            requests = try KeetaEndpoint.temporaryVotes(for: blocks, quotes: quotesInfo, from: repsInfo)
        case .permanent(let temporaryVotes):
            // Determine reps to ask for votes
            let repUrls = Set(try temporaryVotes.map { vote in
                guard let rep = reps.first(where: { $0.address == vote.issuer.publicKeyString }) else {
                    throw KeetaApiError.clientRepresentativeNotFound(vote.issuer.publicKeyString)
                }
                return rep.apiUrl
            })
            requests = try KeetaEndpoint.permanentVotes(for: blocks, temporaryVotes: temporaryVotes, from: repUrls)
        }
        
        // Request votes
        var errors = [Error]()
        
        let votes: [Vote] = try await TaskGroup.load(requests) { request in
            do {
                let result: VoteResponse = try await self.sendRequest(to: request)
                return try Vote.create(from: result.vote.binary)
            } catch {
                if type.isPermanent {
                    // a permanent vote is required for each temporary vote
                    throw error
                } else {
                    if let knownError = error as? RequestError<KeetaErrorResponse>,
                        case .error(_, let keetaError) = knownError  {
                        if keetaError.code == .successorVoteExists {
                            // rep has a vote for a previous block
                            throw error
                        }
                    }
                    
                    // silently skip reps that can't provide a temporary vote
                    errors.append(error)
                    return nil
                }
            }
        }.compactMap { $0 }
        
        guard !votes.isEmpty else {
            throw KeetaApiError.noVotes(errors: errors)
        }
        return votes
    }
    
    public func publish(voteStaple: VoteStaple, toAll: Bool = false) async throws {
        let requests = KeetaEndpoint.publish(voteStaple: voteStaple, to: .init((toAll ? reps : [preferredRep]).map(\.apiUrl)))
        
        // Publish VoteStaple to all known reps, as long as one publish succeeded we can return success
        var succeeded = false
        var latestError: Error?
        
        for request in requests {
            do {
                let response: PublishResponse = try await self.sendRequest(to: request)
                
                if !succeeded && response.publish {
                    succeeded = true
                }
            } catch {
                latestError = error
            }
        }
        
        if succeeded { return }
        
        if let latestError {
            throw latestError
        } else {
            throw KeetaApiError.notPublished
        }
    }
    
    public func pendingBlock(for account: Account) async throws -> Block? {
        let requests = KeetaEndpoint.pendingBlock(for: account, from: .init(reps.map(\.apiUrl)))
        
        var errors = [Error]()
        
        var hashCounts = [String: Int]()
        var blocksWithHashes = [String: Block]()
        
        _ = try await TaskGroup.load(requests) {
            let response: PendingBlockResponse = try await self.sendRequest(to: $0)
            
            guard account.publicKeyString == response.account else {
                throw KeetaApiError.blockAccountMismatch
            }
            
            guard let blockData = response.block else { return }
            
            let block = try Block.create(from: blockData.binary)
            
            guard block.hash == blockData.hash else {
                throw KeetaApiError.blockHashMismatch
            }
            hashCounts[blockData.hash, default: 0] += 1
            blocksWithHashes[blockData.hash] = block
        }
        
        guard !blocksWithHashes.isEmpty else {
            if errors.isEmpty {
                return nil // no pending block
            } else {
                throw KeetaApiError.noPendingBlock(errors: errors)
            }
        }
        
        // Return the block that is repeated on the most reps or the first block
        guard let mostCommonHash = hashCounts.max(by: { $0.value < $1.value })?.key else {
            throw KeetaApiError.noPendingBlock(errors: [NSError(domain: "Most common hash not found", code: 0)])
        }
        return blocksWithHashes[mostCommonHash]
    }
    
    public func recoverVotes(for account: Account) async throws -> [Vote] {
        let repUrl = preferredRep.apiUrl
        let pendingBlockRequest = KeetaEndpoint.pendingBlock(for: account, baseUrl: repUrl)
        let pendingBlockResponse: PendingBlockResponse = try await sendRequest(to: pendingBlockRequest)
        
        guard account.publicKeyString == pendingBlockResponse.account else {
            throw KeetaApiError.blockAccountMismatch
        }
        
        guard let block = pendingBlockResponse.block else {
            return [] // no pending block to recover
        }
        return try await recoverVotes(for: block.hash)
    }
    
    public func recoverVotes(for blockHash: String) async throws -> [Vote] {
        let requests = KeetaEndpoint.vote(for: blockHash, side: .side, repBaseUrls: .init(reps.map(\.apiUrl)))
        
        return try await withThrowingTaskGroup(of: BlockVoteResponse.self) { group in
            for request in requests {
                group.addTask { try await self.sendRequest(to: request) }
            }
            var results = [Vote]()
            for try await result in group {
                if let votes = result.votes {
                    results.append(contentsOf: try votes.map { try Vote.create(from: $0.binary) })
                }
            }
            return results
        }
    }
    
    @discardableResult
    public func publish(blocks: [Block], feeAccount: Account) async throws -> PublishResult {
        try await publish(blocks: blocks) {
            try await BlockBuilder.feeBlock(for: $0, account: feeAccount, api: self)
        }
    }
    
    @discardableResult
    public func publish(
        blocks: [Block],
        quotes: [VoteQuote]? = nil,
        feeBlockBuilder: ((VoteStaple) async throws -> Block)?
    ) async throws -> PublishResult {
        let temporaryVotes = try await votes(for: blocks, type: .temporary(quotes: quotes))
        return try await publish(blocks: blocks, temporaryVotes: temporaryVotes, feeBlockBuilder: feeBlockBuilder)
    }
    
    @discardableResult
    public func publish(
        blocks: [Block],
        temporaryVotes: [Vote],
        feeBlockBuilder: ((VoteStaple) async throws -> Block)?
    ) async throws -> PublishResult {
        let blocksToPublish: [Block]
        let fees: [PublishResult.PaidFee]
        let feeBlockHash: String?
        if temporaryVotes.requiresFees {
            guard let feeBlockBuilder else {
                throw KeetaApiError.feesRequiredButFeeBuilderMissing
            }
            let tempStaple = try VoteStaple.create(from: temporaryVotes, blocks: blocks)
            let feeBlock = try await feeBlockBuilder(tempStaple)
            
            blocksToPublish = blocks + [feeBlock]
            fees = try feeBlock.rawData.operations
                .compactMap { $0 as? SendOperation }
                .map {
                    .init(
                        amount: $0.amount,
                        to: try Account.publicKeyString(from: $0.to),
                        token: try Account.publicKeyString(from: $0.token)
                    )
                }
            feeBlockHash = feeBlock.hash
        } else {
            blocksToPublish = blocks
            fees = []
            feeBlockHash = nil
        }
        
        let permanentVotes = try await votes(for: blocksToPublish, type: .permanent(temporaryVotes: temporaryVotes))
        let voteStaple = try VoteStaple.create(from: permanentVotes, blocks: blocksToPublish)
        try await publish(voteStaple: voteStaple)
        return .init(staple: voteStaple, fees: fees, feeBlockHash: feeBlockHash)
    }
    
    public func block(for hash: String, side: LedgerSide? = nil) async throws -> Block {
        let repUrl = preferredRep.apiUrl
        let endpoint = KeetaEndpoint.block(for: hash, side: side, baseUrl: repUrl)
        let response: BlockResponse = try await sendRequest(to: endpoint)
        let block = try Block.create(from: response.block.binary)
        if let expectedBlockHash = response.blockhash, expectedBlockHash != block.hash {
            throw KeetaApiError.blockHashMismatch
        }
        return block
    }
    
    public func block(for account: Account, idempotent: String, side: LedgerSide = .main) async throws -> Block {
        let repUrl = preferredRep.apiUrl
        let endpoint = KeetaEndpoint.block(for: account, idempotent: idempotent, side: side, baseUrl: repUrl)
        let response: BlockResponse = try await sendRequest(to: endpoint)
        let block = try Block.create(from: response.block.binary)
        if let expectedBlockHash = response.blockhash, expectedBlockHash != block.hash {
            throw KeetaApiError.blockHashMismatch
        }
        return block
    }
    
    public func balance(for account: Account, replaceReps: Bool = false) async throws -> AccountBalance {
        try await updateRepresentatives(replace: replaceReps)
        
        let repUrl = preferredRep.apiUrl
        let result: AccountStateResponse = try await sendRequest(to: KeetaEndpoint.accountInfo(of: account, baseUrl: repUrl))

        var rawBalances = [String: BigInt]()
        for result in result.balances {
            guard let balance = BigInt(hex: result.balance) else {
                throw KeetaApiError.invalidBalanceValue(result.balance)
            }
            rawBalances[result.token] = balance
        }
        
        return .init(account: result.account, rawBalances: rawBalances, currentHeadBlock: result.currentHeadBlock)
    }
    
    @discardableResult
    public func updateRepresentatives(replace: Bool = true) async throws -> [ClientRepresentative] {
        let endpoint = KeetaEndpoint.representatives(baseUrl: preferredRep.apiUrl)
        let response: RepresentativesResponse = try await sendRequest(to: endpoint)
        
        func rep(from rep: RepresentativeResponse) -> ClientRepresentative {
            .init(
                address: rep.representative,
                apiUrl: rep.endpoints.api,
                socketUrl: rep.endpoints.p2p,
                weight: BigInt(hex: rep.weight)
            )
        }
        
        if reps.isEmpty || replace {
            reps = response.representatives.map { rep(from: $0) }
        } else {
            // only update known reps
            for (index, knownRep) in reps.enumerated() {
                if let update = response.representatives
                    .first(where: { $0.representative.lowercased() == knownRep.address.lowercased() }) {
                    reps[index] = rep(from: update)
                }
            }
        }
        
        if let preferredRep = reps.preferred {
            self.preferredRep = preferredRep
        }
        
        return reps
    }
    
    public func accountInfo(for account: Account) async throws -> AccountInfo {
        let repUrl = preferredRep.apiUrl
        let result: AccountStateResponse = try await sendRequest(to: KeetaEndpoint.accountInfo(of: account, baseUrl: repUrl))
        
        let supply: BigInt?
        
        if let supplyRaw = result.info.supply {
            guard let infoSupply = BigInt(hex: supplyRaw) else {
                throw KeetaApiError.invalidSupplyValue(supplyRaw)
            }
            supply = infoSupply
        } else {
            supply = nil
        }
        
        return .init(name: result.info.name, description: result.info.description, metadata: result.info.metadata, supply: supply)
    }
    
    public func history(of account: Account, limit: Int = 50, startBlockHash: String? = nil) async throws -> [VoteStaple] {
        let repUrl = preferredRep.apiUrl
        let request = KeetaEndpoint.history(for: account, limit: limit, startBlockHash: startBlockHash, baseUrl: repUrl)
        let response: HistoryResponse = try await sendRequest(to: request)
        return try response.history.map { try VoteStaple.create(from: $0.voteStaple.binary) }
    }
    
    // MARK: - Internal
    
    private func sendRequest<T: Decodable>(to endpoint: Endpoint) async throws -> T {
        try await sendRequest(to: endpoint, error: KeetaErrorResponse.self, decoder: decoder)
    }
}
