import Foundation

public enum BlockBuilderError: Error {
    case multipleSetRepOperations
    case insufficentDataToSignBlock
    case negativeNetworkId
    case negativeSubnetId
    case noPrivateKeyOrSignatureToSignBlock
    case invalidBalanceValue(String)
    case insufficientBalanceToCoverNetworkFees
    case noFeeEntryForToken
}

public final class BlockBuilder {
    
    internal var version: Block.Version
    internal var purpose: Block.Purpose
    internal var idempotent: String?
    internal var previous: String?
    internal var network: NetworkID?
    internal var subnet: SubnetID?
    internal var account: Account?
    internal var signer: Account?
    internal var operations = [BlockOperation]()
    
    public static func feeBlock(
        for voteStape: VoteStaple,
        account: Account,
        signer: Account? = nil,
        feeToken: Account? = nil,
        network: NetworkConfig
    ) async throws -> Block {
        try await feeBlock(for: voteStape, account: account, signer: signer, feeToken: feeToken, api: KeetaApi(config: network))
    }
    
    public static func feeBlock(
        for voteStape: VoteStaple,
        account: Account,
        signer: Account? = nil,
        feeToken: Account? = nil,
        api: KeetaApi
    ) async throws -> Block {
        let previous: String?
        let resolvedFeeToken: Account?
        if let block = voteStape.blocks.last(where: { $0.rawData.account.publicKeyString == account.publicKeyString }) {
            // latest block hash of account is available within staple
            previous = block.hash
            resolvedFeeToken = feeToken
        } else {
            // fetch latest block hash from account chain
            let balance = try await api.balance(for: account)
            resolvedFeeToken = try balance.selectFeeToken(for: voteStape, baseToken: api.baseToken, preferredToken: feeToken)
            previous = balance.currentHeadBlock
        }

        return try feeBlock(
            for: voteStape,
            account: account,
            signer: signer,
            feeToken: resolvedFeeToken,
            networkId: api.networkId,
            baseToken: api.baseToken,
            previous: previous
        )
    }

    public static func feeBlock(
        for voteStape: VoteStaple,
        account: Account,
        signer: Account? = nil,
        network: NetworkConfig,
        feeToken: Account? = nil,
        previous: String?
    ) throws -> Block {
        try feeBlock(
            for: voteStape,
            account: account,
            signer: signer,
            feeToken: feeToken,
            networkId: network.network.id,
            baseToken: network.baseToken,
            previous: previous
        )
    }

    public static func feeBlock(
        for voteStape: VoteStaple,
        account: Account,
        signer: Account? = nil,
        feeToken: Account? = nil,
        networkId: NetworkID,
        baseToken: Account,
        previous: String?
    ) throws -> Block {
        guard (signer ?? account).canSign else {
            throw BlockBuilderError.insufficentDataToSignBlock
        }

        // Treat an explicit base token as "no preference" aka nil
        let preferredFeeToken: Account? = feeToken?.publicKeyString == baseToken.publicKeyString ? nil : feeToken

        // Pay each vote issuer aka rep their respected fee
        var operations = [SendOperation]()
        for vote in voteStape.votes {
            if let fee = vote.fee {
                let entry: FeeEntry
                if let preferredFeeToken {
                    guard let match = fee.entry(for: preferredFeeToken) else {
                        throw BlockBuilderError.noFeeEntryForToken
                    }
                    entry = match
                } else {
                    // Prefer base token, fall back to first available entry
                    guard let match = fee.entry(for: baseToken, isBaseToken: true) ?? fee.entries.first else {
                        throw BlockBuilderError.noFeeEntryForToken
                    }
                    entry = match
                }
                let send = try SendOperation(
                    amount: TokenAmount(raw: entry.amount),
                    to: entry.payTo ?? vote.issuer,
                    token: entry.token ?? baseToken
                )
                operations.append(send)
            }
        }

        return try BlockBuilder(purpose: .fee)
            .start(from: previous, network: networkId)
            .add(account: account)
            .add(signer: signer)
            .add(operations: operations)
            .seal()
    }
    
    public static func idempotentKey() -> String {
        try! UUID().uuidString.idempotent()
    }
    
    public init(version: Block.Version = .latest, purpose: Block.Purpose = .generic) {
        self.version = version
        self.purpose = purpose
    }
    
    public func start(from previous: String?, config: NetworkConfig, subnet: SubnetID? = nil) -> BlockBuilder {
        start(from: previous, network: config.network.id, subnet: subnet)
    }
    
    public func start(from previous: String?, network: NetworkAlias, subnet: SubnetID? = nil) -> BlockBuilder {
        start(from: previous, network: network.id, subnet: subnet)
    }
    
    public func start(from previous: String?, network: NetworkID, subnet: SubnetID? = nil) -> BlockBuilder {
        self.previous = previous?.uppercased()
        self.network = network
        self.subnet = subnet
        
        return self
    }
    
    public func add(account: Account) -> BlockBuilder {
        self.account = account
        
        return self
    }
    
    public func add(idempotent: String?) -> BlockBuilder {
        self.idempotent = idempotent
        
        return self
    }
    
    public func add(signer: Account?) -> BlockBuilder {
        self.signer = signer
        
        return self
    }
    
    // Wait for splatting: https://github.com/swiftlang/swift/issues/42750
    public func add(operations: [BlockOperation]) throws -> BlockBuilder {
        var latest = self
        try operations.forEach { latest = try latest.add(operation: $0) }
        return latest
    }
    
    public func add(operations: BlockOperation...) throws -> BlockBuilder {
        var latest = self
        try operations.forEach { latest = try latest.add(operation: $0) }
        return latest
    }
    
    public func add(operation: BlockOperation) throws -> BlockBuilder {
        if operation.operationType == .setRep && operations.contains(where: { $0.operationType == .setRep }) {
            throw BlockBuilderError.multipleSetRepOperations
        }
        
        operations.append(operation)
        
        return self
    }
    
    public func seal(with signature: Signature? = nil, created: Date = .init()) throws -> Block {
        guard let network = network,
              let signer = signer ?? account,
              !operations.isEmpty else {
            throw BlockBuilderError.insufficentDataToSignBlock
        }
        
        if network < 0 {
            throw BlockBuilderError.negativeNetworkId
        }
        
        if let subnet = subnet, subnet < 0 {
            throw BlockBuilderError.negativeSubnetId
        }
        
        // ensure block can be signed, if no signature was provided
        if signature == nil && !signer.canSign {
            throw BlockBuilderError.noPrivateKeyOrSignatureToSignBlock
        }
        
        let account = self.account ?? signer
        
        let previousHash: String
        if let previous = previous {
            previousHash = previous
        } else {
            previousHash = try Block.accountOpeningHash(for: account)
        }
        
        let rawBlock = RawBlockData(
            version: version,
            purpose: purpose,
            idempotent: idempotent,
            previous: previousHash,
            network: network,
            subnet: subnet,
            signer: .single(signer),
            account: account,
            operations: operations,
            created: created
        )
        
        return try Block(from: rawBlock, opening: previous == nil, signature: signature)
    }
}
