import Foundation
import BigInt

public enum KeetaApiError: Error {
    case invalidBalanceValue(_ value: String)
    case invalidSupplyValue(_ value: String)
    case clientRepresentativeNotFound(_ address: String)
    case noVotes(errors: [Error])
    case missingAtLeastOneRep
    case feesRequiredButFeeBuilderMissing
    case blockMismatch
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
    
    public func votes(for blocks: [Block], temporaryVotes: [Vote]? = nil) async throws -> [Vote] {
        let repUrls: Set<String>
        
        // Determine reps to ask for votes
        if let temporaryVotes, !temporaryVotes.isEmpty {
            repUrls = .init(try temporaryVotes.map { vote in
                guard let rep = reps.first(where: { $0.address == vote.issuer.publicKeyString }) else {
                    throw KeetaApiError.clientRepresentativeNotFound(vote.issuer.publicKeyString)
                }
                return rep.apiUrl
            })
        } else {
            repUrls = .init(reps.map(\.apiUrl))
        }
        
        // Request votes
        let requests = try KeetaEndpoint.votes(for: blocks, temporaryVotes: temporaryVotes, from: repUrls)
        var errors = [Error]()
        
        return try await withThrowingTaskGroup(of: VoteResponse?.self) { group in
            for request in requests {
                group.addTask {
                    do {
                        return try await self.sendRequest(to: request)
                    } catch {
                        if temporaryVotes?.isEmpty == false {
                            // a permanent vote is required for each temporary vote
                            throw error
                        } else {
                            // silently skip reps that can't provide a temporary vote
                            errors.append(error)
                            return nil
                        }
                    }
                }
            }
            
            var results: [Vote] = []
            for try await result in group {
                if let result {
                    let vote = try Vote.create(from: result.vote.binary)
                    results.append(vote)
                }
            }
            
            guard !results.isEmpty else {
                throw KeetaApiError.noVotes(errors: errors)
            }
            
            return results
        }
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
    
    public func recoverVotes(for account: Account) async throws -> [Vote] {
        let repUrl = preferredRep.apiUrl
        let pendingBlockRequest = KeetaEndpoint.pendingBlock(for: account, baseUrl: repUrl)
        let pendingBlockResponse: PendingBlockResponse = try await sendRequest(to: pendingBlockRequest)
        
        guard account.publicKeyString == pendingBlockResponse.account else {
            throw KeetaApiError.blockMismatch
        }
        
        guard let block = pendingBlockResponse.block else {
            return [] // no pending block to recover
        }
        
        let requests = KeetaEndpoint.vote(for: block.hash, side: .side, repBaseUrls: .init(reps.map(\.apiUrl)))
        
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
    
    public func publish(blocks: [Block], account: Account) async throws {
        try await publish(blocks: blocks) {
            try BlockBuilder.feeBlock(for: $0, account: account, networkId: self.networkId, baseToken: self.baseToken)
        }
    }
    
    public func publish(blocks: [Block], feeBlockBuilder: ((VoteStaple) throws -> Block)?) async throws {
        let temporaryVotes = try await votes(for: blocks)
        
        let blocksToPublish: [Block]
        if temporaryVotes.requiresFees {
            guard let feeBlockBuilder else {
                throw KeetaApiError.feesRequiredButFeeBuilderMissing
            }
            let tempStaple = try VoteStaple.create(from: temporaryVotes, blocks: blocks)
            blocksToPublish = blocks + [try feeBlockBuilder(tempStaple)]
        } else {
            blocksToPublish = blocks
        }
        
        let permanentVotes = try await votes(for: blocksToPublish, temporaryVotes: temporaryVotes)
        let voteStaple = try VoteStaple.create(from: permanentVotes, blocks: blocksToPublish)
        try await publish(voteStaple: voteStaple)
    }
    
    public func balance(for account: Account, replaceReps: Bool = false) async throws -> AccountBalance {
        try await updateRepresentatives(replace: replaceReps)
        
        let repUrl = preferredRep.apiUrl
        let result: AccountStateResponse = try await sendRequest(to: KeetaEndpoint.accountInfo(of: account, baseUrl: repUrl))

        var balances = [String: BigInt]()
        for result in result.balances {
            guard let balance = BigInt(hex: result.balance) else {
                throw KeetaApiError.invalidBalanceValue(result.balance)
            }
            balances[result.token] = balance
        }
        
        return .init(account: result.account, balances: balances, currentHeadBlock: result.currentHeadBlock)
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
