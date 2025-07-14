import Foundation

public enum BlockBuilderError: Error {
    case unsupportedBlockVersion
    case multipleSetRepOperations
    case insufficentDataToSignBlock
    case negativeNetworkId
    case negativeSubnetId
    case noPrivateKeyOrSignatureToSignBlock
    case invalidBalanceValue(String)
}

public final class BlockBuilder {
    
    internal var version: Block.Version
    internal var previous: String?
    internal var network: NetworkID?
    internal var subnet: SubnetID?
    internal var account: Account?
    internal var signer: Account?
    internal var operations = [BlockOperation]()
    
    public static let currentVersion: Block.Version = 1

    public init(version: Block.Version = currentVersion) throws {
        if version != Self.currentVersion {
            throw BlockBuilderError.unsupportedBlockVersion
        }
        self.version = version
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
            previous: previousHash,
            network: network,
            subnet: subnet,
            signer: signer,
            account: account,
            operations: operations,
            created: created
        )
        
        return try Block(from: rawBlock, opening: previous == nil, signature: signature)
    }
}
