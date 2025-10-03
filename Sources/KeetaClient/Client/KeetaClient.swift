import Foundation
import BigInt

public enum KeetaNetwork {
    case test
    case main
}

public enum KeetaClientError: Error {
    case missingAccount
    case invalidTokenAccount
    case feeAccountMissing
    case noTokenAccount
    case noTokenSupply
}

public final class KeetaClient {
    
    public let api: KeetaApi
    public let config: NetworkConfig
    public let version: Block.Version
    public let account: Account?
    public var feeAccount: Account?
    
    public convenience init(network: KeetaNetwork, version: Block.Version = .latest, account: Account, usedToPayFees: Bool = true) {
        self.init(network: network, version: version, account: account, feeAccount: usedToPayFees ? account : nil)
    }

    public init(network: KeetaNetwork, version: Block.Version = .latest, account: Account? = nil, feeAccount: Account? = nil) {
        let alias: NetworkAlias = switch network {
        case .test: .test
        case .main: .main
        }
        
        self.config = try! .create(for: alias)
        self.version = version
        self.account = account
        self.feeAccount = feeAccount
        
        api = try! .init(config: config)
    }
    
    // MARK: Send
    
    @discardableResult
    public func send(amount: BigInt, to toPubKeyAccount: String, signer: Account? = nil, memo: String? = nil) async throws -> String {
        let toAccount = try AccountBuilder.create(fromPublicKey: toPubKeyAccount)
        return try await send(amount: amount, to: toAccount, signer: signer, memo: memo)
    }
    
    @discardableResult
    public func send(amount: BigInt, to toAccount: Account, signer: Account? = nil, memo: String? = nil) async throws -> String {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await send(amount: amount, from: account, to: toAccount, signer: signer, memo: memo)
    }
    
    @discardableResult
    public func send(amount: BigInt, to toAccount: Account, token tokenPubKey: String, signer: Account? = nil, memo: String? = nil) async throws -> String {
        guard let account else { throw KeetaClientError.missingAccount }
        let token = try AccountBuilder.create(fromPublicKey: tokenPubKey)
        return try await send(amount: amount, from: account, to: toAccount, token: token, signer: signer, memo: memo)
    }
    
    @discardableResult
    public func send(amount: BigInt, to toAccount: Account, token: Account, signer: Account? = nil, memo: String? = nil) async throws -> String {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await send(amount: amount, from: account, to: toAccount, token: token, signer: signer, memo: memo)
    }
    
    @discardableResult
    public func send(amount: BigInt, from fromAccount: Account, to toPubKeyAccount: String, memo: String? = nil) async throws -> String {
        let toAccount = try AccountBuilder.create(fromPublicKey: toPubKeyAccount)
        return try await send(amount: amount, from: fromAccount, to: toAccount, memo: memo)
    }
    
    @discardableResult
    public func send(amount: BigInt, from fromAccount: Account, to toAccount: Account, signer: Account? = nil, memo: String? = nil) async throws -> String {
        try await send(amount: amount, from: fromAccount, to: toAccount, token: config.baseToken, signer: signer, memo: memo)
    }
    
    @discardableResult
    public func send(amount: BigInt, from fromAccount: Account, to toPubKeyAccount: String, token tokenPubKey: String, signer: Account? = nil, memo: String? = nil) async throws -> String {
        let toAccount = try AccountBuilder.create(fromPublicKey: toPubKeyAccount)
        let token = try AccountBuilder.create(fromPublicKey: tokenPubKey)
        return try await send(amount: amount, from: fromAccount, to: toAccount, token: token, signer: signer, memo: memo)
    }
    
    @discardableResult
    public func send(
        amount: BigInt,
        from fromAccount: Account,
        to toAccount: Account,
        token: Account,
        signer: Account? = nil,
        feeAccount: Account? = nil,
        memo: String? = nil
    ) async throws -> String {
        guard token.keyAlgorithm == .TOKEN else {
            throw KeetaClientError.invalidTokenAccount
        }
        
        let balance = try await api.balance(for: fromAccount)
        let send = try SendOperation(amount: amount, to: toAccount, token: token, external: memo)
        
        let sendBlock = try blockBuilder()
            .start(from: balance.currentHeadBlock, network: config.networkID)
            .add(account: fromAccount)
            .add(operation: send)
            .add(signer: signer)
            .seal()
        
        try await api.publish(blocks: [sendBlock]) {
            let accountToPayFees: Account
            if let feeAccount = feeAccount ?? self.feeAccount,
               feeAccount.publicKeyString != fromAccount.publicKeyString {
                accountToPayFees = feeAccount
            } else {
                let fees = $0.totalFees(baseToken: self.config.baseToken)
                
                guard balance.canCover(fees: fees) else {
                    throw BlockBuilderError.insufficientBalanceToCoverNetworkFees
                }
                
                accountToPayFees = fromAccount
            }
            return try await BlockBuilder.feeBlock(for: $0, account: accountToPayFees, network: self.config)
        }
        
        return sendBlock.hash
    }
    
    // MARK: Balance
    
    public func balance() async throws -> AccountBalance {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await balance(of: account)
    }
    
    public func balance(of accountPubKey: String) async throws -> AccountBalance {
        let account = try AccountBuilder.create(fromPublicKey: accountPubKey)
        return try await balance(of: account)
    }
    
    public func balance(of account: Account) async throws -> AccountBalance {
        try await api.balance(for: account)
    }
    
    // MARK: Transactions
    
    public func transactions(limit: Int = 100, startBlockHash: String? = nil) async throws -> [Transaction] {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await transactions(for: account, limit: limit, startBlockHash: startBlockHash)
    }
    
    public func transactions(for accountPubKey: String, limit: Int = 100, startBlockHash: String? = nil) async throws -> [Transaction] {
        let account = try AccountBuilder.create(fromPublicKey: accountPubKey)
        return try await transactions(for: account, limit: limit, startBlockHash: startBlockHash)
    }
    
    public func transactions(for account: Account, limit: Int = 100, startBlockHash: String? = nil) async throws -> [Transaction] {
        let history = try await api.history(of: account, limit: limit, startBlockHash: startBlockHash)
        
        var transactions = [Transaction]()
        
        for staple in history {
            for block in staple.blocks {
                for operation in block.rawData.operations {
                    switch operation.operationType {
                    case .send:
                        let send = try operation.to(SendOperation.self)
                        let toAccount = try Account(publicKeyAndType: send.to)
                        let isComing = toAccount.publicKeyString == account.publicKeyString
                        
                        // ignore outgoing send operations as they aren't effecting the account's chain
                        if !isComing && block.rawData.account.publicKeyString != account.publicKeyString { continue }
                        
                        transactions.append(
                            Transaction(
                                amount: send.amount,
                                from: isComing ? block.rawData.account : account,
                                to: isComing ? account : toAccount,
                                token: try Account(publicKeyAndType: send.token),
                                isNetworkFee: block.rawData.purpose == .fee,
                                created: block.rawData.created,
                                memo: send.external
                            )
                        )
                    case .receive:
                        let receive = try operation.to(ReceiveOperation.self)
                        let fromAccount = try Account(publicKeyAndType: receive.from)
                        let isOutgoing = fromAccount.publicKeyString == account.publicKeyString
                        
                        transactions.append(
                            Transaction(
                                amount: receive.amount,
                                from: isOutgoing ? account : fromAccount,
                                to: isOutgoing ? fromAccount : account,
                                token: try Account(publicKeyAndType: receive.token),
                                isNetworkFee: false,
                                created: block.rawData.created,
                                memo: nil
                            )
                        )
                    default: break
                    }
                }
            }
        }
        
        return transactions.sorted { $0.created > $1.created }
    }
    
    // MARK: Swap
    
    public func swap(with otherAccount: Account, offer: Proposal, ask: Proposal, feeAccount: Account? = nil) async throws {
        guard let account else { throw KeetaClientError.missingAccount }
        try await swap(account: account, offer: offer, ask: ask, from: otherAccount, feeAccount: feeAccount)
    }
    
    @discardableResult
    public func swap(account: Account, offer: Proposal, ask: Proposal, from otherAccount: Account, feeAccount: Account? = nil) async throws -> PublishResult {
        guard let feeAccount = feeAccount ?? self.feeAccount else {
            throw KeetaClientError.feeAccountMissing
        }
        
        let receive = try ReceiveOperation(amount: ask.amount, token: ask.token, from: otherAccount, exact: true)
        
        let accountHeadblock = try await api.balance(for: account).currentHeadBlock
        let needToReceiveBlock = try blockBuilder()
            .start(from: accountHeadblock, network: config.networkID)
            .add(account: account)
            .add(operation: receive)
            .seal()
        
        let accountTokenSend = try SendOperation(amount: offer.amount, to: otherAccount, token: offer.token)
        let accountTokenSendBlock = try blockBuilder()
            .start(from: needToReceiveBlock.hash, network: config.networkID)
            .add(account: account)
            .add(operation: accountTokenSend)
            .seal()
        
        let otherAccountHeadblock = try await api.balance(for: otherAccount).currentHeadBlock
        let otherAccountTokenSend = try SendOperation(amount: ask.amount, to: account, token: ask.token)
        let otherAccountTokenSendBlock = try blockBuilder()
            .start(from: otherAccountHeadblock, network: config.networkID)
            .add(account: otherAccount)
            .add(operation: otherAccountTokenSend)
            .seal()
        
        let blocks = [otherAccountTokenSendBlock, needToReceiveBlock, accountTokenSendBlock]
        return try await api.publish(blocks: blocks) {
            try await BlockBuilder.feeBlock(for: $0, account: feeAccount, network: self.config)
        }
    }
    
    // MARK: Token Management
    
    public func createToken(
        name: String, supply: Double, description: String = "", feeAccount: Account? = nil
    ) async throws -> Account {
        try await createToken(name: name, supply: BigInt(supply), feeAccount: feeAccount)
    }
    
    public func createToken(
        name: String, supply: BigInt, feeAccount: Account? = nil
    ) async throws -> Account {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await createToken(
            for: account, name: name, supply: supply, feeAccount: feeAccount
        )
    }
    
    public func createToken(
        for account: Account,
        name: String,
        supply: BigInt,
        feeAccount: Account? = nil
    ) async throws -> Account {
        let token = try account.generateIdentifier()
        
        let create = CreateIdentifierOperation(identifier: token)
        let tokenCreationBlock = try blockBuilder()
            .start(from: nil, network: config.networkID)
            .add(signer: account)
            .add(operation: create)
            .seal()
        
        let mint = TokenAdminSupplyOperation(amount: supply, method: .add)
        let info = SetInfoOperation(name: name, defaultPermission: .init(baseFlag: .ACCESS))
        let tokenMintBlock = try blockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: token)
            .add(operations: mint, info)
            .add(signer: account)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock]) {
            try await BlockBuilder.feeBlock(for: $0, account: feeAccount ?? account, api: self.api)
        }
        
        return token
    }
    
    // MARK: Helper
    
    private func blockBuilder() -> BlockBuilder {
        .init(version: version)
    }
}
