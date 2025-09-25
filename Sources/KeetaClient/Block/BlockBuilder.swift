import Foundation

public enum BlockBuilderError: Error {
    case multipleSetRepOperations
    case insufficentDataToSignBlock
    case negativeNetworkId
    case negativeSubnetId
    case noPrivateKeyOrSignatureToSignBlock
    case invalidBalanceValue(String)
    case feeBlockPreviousHashNotFound
}

public final class BlockBuilder {
    
    internal var version: Block.Version
    internal var purpose: Block.Purpose
    internal var previous: String?
    internal var network: NetworkID?
    internal var subnet: SubnetID?
    internal var account: Account?
    internal var signer: Account?
    internal var operations = [BlockOperation]()
    
    public static func feeBlock(
        for voteStape: VoteStaple,
        account: Account,
        network: NetworkAlias
    ) throws -> Block {
        try feeBlock(for: voteStape, account: account, network: .create(for: network))
    }
    
    public static func feeBlock(
        for voteStape: VoteStaple,
        account: Account,
        network: NetworkConfig
    ) throws -> Block {
        try feeBlock(for: voteStape, account: account, networkId: network.networkID, baseToken: network.baseToken)
    }
    
    public static func feeBlock(
        for voteStape: VoteStaple,
        account: Account,
        networkId: NetworkID,
        baseToken: Account
    ) throws -> Block {
        guard account.canSign else {
            throw BlockBuilderError.insufficentDataToSignBlock
        }
        
        guard let previous = voteStape.blocks
            .last(where: { $0.rawData.account.publicKeyString == account.publicKeyString })?.hash else {
                throw BlockBuilderError.feeBlockPreviousHashNotFound
            }
        
        // Pay each vote issuer aka rep their respected fee
        var operations = [SendOperation]()
        for vote in voteStape.votes {
            if let fee = vote.fee {
                let send = try SendOperation(
                    amount: fee.amount,
                    to: fee.payTo ?? vote.issuer,
                    token: fee.token ?? baseToken
                )
                operations.append(send)
            }
        }
        
        return try BlockBuilder(purpose: .fee)
            .start(from: previous, network: networkId)
            .add(account: account)
            .add(operations: operations)
            .seal()
    }
    
    public init(version: Block.Version = .latest, purpose: Block.Purpose = .generic) {
        self.version = version
        self.purpose = purpose
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
            previous: previousHash,
            network: network,
            subnet: subnet,
            signer: signer,
            account: account,
            operations: operations,
            created: created
        )
        
        return try Block(from: rawBlock, opening: previous == nil, signature: signature.map { .single($0) })
    }
}
