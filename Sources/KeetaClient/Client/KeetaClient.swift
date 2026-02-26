import Foundation
import BigInt

public enum KeetaClientError: Error {
    case missingAccount
    case invalidTokenAccount
    case feeAccountMissing
    case noTokenAccount
    case noTokenSupply
}

public struct Options {
    public let idempotency: String?
    public let signer: Account?
    public let feeAccount: Account?
    public let memo: String?
    
    public init(idempotency: String? = nil, signer: Account? = nil, feeAccount: Account? = nil, memo: String? = nil) {
        self.idempotency = idempotency
        self.signer = signer
        self.feeAccount = feeAccount
        self.memo = memo
    }
}

public final class KeetaClient {
    
    public let api: KeetaApi
    public let config: NetworkConfig
    public let version: Block.Version
    public let account: Account?
    public var feeAccount: Account?
    
    public convenience init(network: NetworkAlias, version: Block.Version = .latest, account: Account, usedToPayFees: Bool = true) {
        self.init(network: network, version: version, account: account, feeAccount: usedToPayFees ? account : nil)
    }

    public convenience init(network: NetworkAlias, version: Block.Version = .latest, account: Account? = nil, feeAccount: Account? = nil) {
        self.init(config: try! .create(for: network), version: version, account: account, feeAccount: feeAccount)
    }
    
    public init(config: NetworkConfig, version: Block.Version = .latest, account: Account? = nil, feeAccount: Account? = nil) {
        self.config = config
        self.version = version
        self.account = account
        self.feeAccount = feeAccount
        
        api = try! .init(config: config)
    }
    
    // MARK: Send
    
    @discardableResult
    public func send(amount: BigInt, to toPubKeyAccount: String, options: Options? = nil) async throws -> PublishResult {
        let toAccount = try AccountBuilder.create(fromPublicKey: toPubKeyAccount)
        return try await send(amount: amount, to: toAccount, options: options)
    }
    
    @discardableResult
    public func send(amount: BigInt, to toAccount: Account, options: Options? = nil) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await send(amount: amount, from: account, to: toAccount, options: options)
    }
    
    @discardableResult
    public func send(amount: BigInt, to toPubKeyAccount: String, token tokenPubKey: String, options: Options? = nil) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        let token = try AccountBuilder.create(fromPublicKey: tokenPubKey)
        let toAccount = try AccountBuilder.create(fromPublicKey: toPubKeyAccount)
        return try await send(amount: amount, from: account, to: toAccount, token: token, options: options)
    }
    
    @discardableResult
    public func send(amount: BigInt, to toAccount: Account, token tokenPubKey: String, options: Options? = nil) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        let token = try AccountBuilder.create(fromPublicKey: tokenPubKey)
        return try await send(amount: amount, from: account, to: toAccount, token: token, options: options)
    }
    
    @discardableResult
    public func send(amount: BigInt, to toAccount: Account, token: Account, options: Options? = nil) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await send(amount: amount, from: account, to: toAccount, token: token, options: options)
    }
    
    @discardableResult
    public func send(amount: BigInt, from fromAccount: Account, to toAccount: Account, options: Options? = nil) async throws -> PublishResult {
        try await send(amount: amount, from: fromAccount, to: toAccount, token: config.baseToken, options: options)
    }
    
    @discardableResult
    public func send(amount: BigInt, from fromAccount: Account, to toPubKeyAccount: String, token tokenPubKey: String, options: Options? = nil) async throws -> PublishResult {
        let toAccount = try AccountBuilder.create(fromPublicKey: toPubKeyAccount)
        let token = try AccountBuilder.create(fromPublicKey: tokenPubKey)
        return try await send(amount: amount, from: fromAccount, to: toAccount, token: token, options: options)
    }
    
    @discardableResult
    public func send(
        amount: BigInt,
        from fromAccount: Account,
        to toAccount: Account,
        token: Account,
        options: Options? = nil
    ) async throws -> PublishResult {
        guard token.keyAlgorithm == .TOKEN else {
            throw KeetaClientError.invalidTokenAccount
        }
        
        let balance = try await api.balance(for: fromAccount)
        let send = try SendOperation(amount: amount, to: toAccount, token: token, external: options?.memo)
        
        let sendBlock = try blockBuilder()
            .start(from: balance.currentHeadBlock, network: config.network.id)
            .add(account: fromAccount)
            .add(operation: send)
            .add(idempotent: options?.idempotency)
            .add(signer: options?.signer)
            .seal()
        
        let result = try await api.publish(blocks: [sendBlock]) {
            let accountToPayFees: Account
            if let feeAccount = options?.feeAccount ?? self.feeAccount,
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
        
        return result
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
    
    public func transactions(limit: Int = 100, startBlocksHash: String? = nil) async throws -> [NetworkTransaction] {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await transactions(for: account, limit: limit, startBlocksHash: startBlocksHash)
    }
    
    public func transactions(for accountPubKey: String, limit: Int = 100, startBlocksHash: String? = nil) async throws -> [NetworkTransaction] {
        let account = try AccountBuilder.create(fromPublicKey: accountPubKey)
        return try await transactions(for: account, limit: limit, startBlocksHash: startBlocksHash)
    }
    
    public func transactions(for account: Account, limit: Int = 100, startBlocksHash: String? = nil) async throws -> [NetworkTransaction] {
        let history = try await api.history(of: account, limit: limit, startBlocksHash: startBlocksHash)
        
        var transactions = [NetworkTransaction]()
        
        for staple in history {
            var idIterator: UInt8 = 1
            for block in staple.blocks {
                for operation in block.rawData.operations {
                    
                    let id: String = Hash.create(from: try staple.blocksHash.toBytes() + [idIterator])
                    
                    switch operation.operationType {
                    case .send:
                        let send = try operation.to(SendOperation.self)
                        let toAccount = try Account(publicKeyAndType: send.to)
                        let isIncoming = toAccount.publicKeyString == account.publicKeyString
                        
                        // ignore send operations that aren't effecting the account's chain
                        if !isIncoming && block.rawData.account.publicKeyString != account.publicKeyString { continue }
                        
                        let sendTransaction = NetworkSendTransaction(
                            id: id,
                            blockHash: block.hash,
                            stapleHash: staple.blocksHash,
                            amount: send.amount,
                            from: isIncoming ? block.rawData.account : account,
                            to: isIncoming ? account : toAccount,
                            token: try Account(publicKeyAndType: send.token),
                            isIncoming: isIncoming,
                            isNetworkFee: block.rawData.purpose == .fee,
                            created: block.rawData.created,
                            memo: send.external
                        )
                        transactions.append(.send(sendTransaction))
                    case .receive:
                        let receive = try operation.to(ReceiveOperation.self)
                        let fromAccount = try Account(publicKeyAndType: receive.from)
                        let isFromAccount = fromAccount.publicKeyString == account.publicKeyString
                        let isToAccount = block.rawData.account.publicKeyString == account.publicKeyString
                        
                        // ignore receive operations that aren't effecting the account's chain
                        guard isFromAccount || isToAccount else { continue }
                        
                        let receiveTransaction = NetworkReceiveTransaction(
                            id: id,
                            blockHash: block.hash,
                            stapleHash: staple.blocksHash,
                            amount: receive.amount,
                            from: fromAccount,
                            to: block.rawData.account,
                            token: try Account(publicKeyAndType: receive.token),
                            created: block.rawData.created
                        )
                        transactions.append(.receive(receiveTransaction))
                    default: break
                    }
                    
                    idIterator += 1
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
        
        let send = try SendOperation(amount: offer.amount, to: otherAccount, token: offer.token)
        let receive = try ReceiveOperation(amount: ask.amount, token: ask.token, from: otherAccount, exact: true)
        
        let accountHeadblock = try await api.balance(for: account).currentHeadBlock
        
        let accountSendReceiveBlock = try blockBuilder()
            .start(from: accountHeadblock, network: config.network.id)
            .add(account: account)
            .add(operations: receive, send)
            .seal()
        
        let otherAccountHeadblock = try await api.balance(for: otherAccount).currentHeadBlock
        let otherAccountTokenSend = try SendOperation(amount: ask.amount, to: account, token: ask.token)
        let otherAccountTokenSendBlock = try blockBuilder()
            .start(from: otherAccountHeadblock, network: config.network.id)
            .add(account: otherAccount)
            .add(operation: otherAccountTokenSend)
            .seal()
        
        let blocks = [otherAccountTokenSendBlock, accountSendReceiveBlock]
        return try await api.publish(blocks: blocks) {
            try await BlockBuilder.feeBlock(for: $0, account: feeAccount, network: self.config)
        }
    }
    
    // MARK: Token Management
    
    public func createToken(
        name: String, supply: Int, decimals: Int = 9, description: String = "", icon: TokenIcon? = nil, feeAccount: Account? = nil
    ) async throws -> Account {
        try await createToken(name: name, supply: BigInt(supply), decimals: decimals, description: description, icon: icon, feeAccount: feeAccount)
    }
    
    public func createToken(
        name: String, supply: BigInt, decimals: Int = 9, description: String = "", icon: TokenIcon? = nil, feeAccount: Account? = nil
    ) async throws -> Account {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await createToken(
            for: account, name: name, supply: supply, decimals: decimals, description: description, icon: icon, feeAccount: feeAccount
        )
    }
    
    public func createToken(
        for account: Account,
        name: String,
        supply: BigInt,
        decimals: Int = 9,
        description: String = "",
        icon: TokenIcon? = nil,
        feeAccount: Account? = nil
    ) async throws -> Account {
        let accountHeadblock = try await api.balance(for: account).currentHeadBlock
        let token = try account.generateIdentifier(previous: accountHeadblock)

        let create = CreateIdentifierOperation(identifier: token)
        let tokenCreationBlock = try blockBuilder()
            .start(from: accountHeadblock, network: config.network.id)
            .add(account: account)
            .add(operation: create)
            .seal()
        
        let mint = TokenAdminSupplyOperation(amount: supply, method: .add)
        
        // Token Meta Data
        let info = SetInfoOperation(
            name: name,
            description: description,
            metaData: try MetaData(decimalPlaces: decimals, icon: icon).btoa(),
            defaultPermission: .init(baseFlags: [.ACCESS])
        )
        
        let tokenMintBlock = try blockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: token)
            .add(operations: mint, info)
            .add(signer: account)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock]) {
            try await BlockBuilder.feeBlock(for: $0, account: feeAccount ?? account, api: self.api)
        }
        
        return token
    }
    
    public func tokenInfo() async throws -> TokenInfo {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await tokenInfo(for: account)
    }
    
    public func tokenInfo(for pubKeyAccount: String) async throws -> TokenInfo {
        let account = try AccountBuilder.create(fromPublicKey: pubKeyAccount)
        return try await tokenInfo(for: account)
    }
    
    public func tokenInfo(for account: Account) async throws -> TokenInfo {
        guard account.keyAlgorithm == .TOKEN else {
            throw KeetaClientError.noTokenAccount
        }
        
        let accountInfo = try await api.accountInfo(for: account)
        
        // Tokens without supply or decimal places meta data are considered invalid
        let metaData = try MetaData.create(from: accountInfo.metadata)
        
        guard let supply = accountInfo.supply else {
            throw KeetaClientError.noTokenSupply
        }
        
        return TokenInfo(
            address: account.publicKeyString,
            name: accountInfo.name,
            description: accountInfo.description.isEmpty ? nil : accountInfo.description,
            supply: Double(supply),
            decimalPlaces: metaData.decimalPlaces,
            icon: .create(from: metaData.logoURI)
        )
    }
    
    // MARK: Account
    
    public enum RecoverResult {
        case published(PublishResult)
        case readyToPublish([Block], temporaryVotes: [Vote])
    }
    
    public func recoverAccount(publish: Bool = true, feeAccount: Account? = nil) async throws -> RecoverResult? {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await recoverAccount(account, publish: publish, feeAccount: feeAccount)
    }
    
    public func recoverAccount(
        _ account: Account, publish: Bool = true, feeAccount: Account? = nil
    ) async throws -> RecoverResult? {
        guard let pendingBlock = try await api.pendingBlock(for: account) else { return nil }
        
        let recoveredTemporaryVotes = try await api.recoverVotes(for: pendingBlock.hash)
        
        let feeAccount = feeAccount ?? self.feeAccount ?? account
        
        if publish {
            let result = try await api.publish(blocks: [pendingBlock], temporaryVotes: recoveredTemporaryVotes) {
                try await BlockBuilder.feeBlock(for: $0, account: feeAccount, network: self.config)
            }
            return .published(result)
        } else {
            let blocksToPublish: [Block]
            if recoveredTemporaryVotes.requiresFees {
                let recoveredStaple = try VoteStaple.create(from: recoveredTemporaryVotes, blocks: [pendingBlock])
                let fee = try await BlockBuilder.feeBlock(for: recoveredStaple, account: feeAccount, network: self.config)
                blocksToPublish = [pendingBlock, fee]
            } else {
                blocksToPublish = [pendingBlock]
            }
            return .readyToPublish(blocksToPublish, temporaryVotes: recoveredTemporaryVotes)
        }
    }
    
    // MARK: Permissions
    
    @discardableResult
    public func grantPermissions(
        _ flags: [Permission.BaseFlag],
        to principal: Account,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await grantPermissions(flags, account: account, to: principal, feeAccount: feeAccount)
    }
    
    @discardableResult
    public func grantPermissions(
        _ flags: [Permission.BaseFlag],
        to principalPubKey: String,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        let principal = try AccountBuilder.create(fromPublicKey: principalPubKey)
        return try await grantPermissions(flags, account: account, to: principal, feeAccount: feeAccount)
    }
    
    @discardableResult
    public func grantPermissions(
        _ flags: [Permission.BaseFlag],
        account: Account,
        to principalPubKey: String,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        let principal = try AccountBuilder.create(fromPublicKey: principalPubKey)
        return try await grantPermissions(flags, account: account, to: principal, feeAccount: feeAccount)
    }
    
    @discardableResult
    public func grantPermissions(
        _ flags: [Permission.BaseFlag],
        account: Account,
        to principal: Account,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        let modifyPermission = ModifyPermissionsOperation(
            principal: principal,
            method: .set,
            permission: Permission(baseFlags: flags.contains(.ACCESS) ? flags : [.ACCESS] + flags)
        )
        
        let accountHeadblock = try await api.balance(for: account).currentHeadBlock

        let modifyBlock = try BlockBuilder()
            .start(from: accountHeadblock, network: config.network.id)
            .add(account: account)
            .add(operation: modifyPermission)
            .seal()
        
        return try await api.publish(blocks: [modifyBlock], feeAccount: feeAccount ?? self.feeAccount ?? account)
    }
    
    @discardableResult
    public func removePermissions(
        _ flags: [Permission.BaseFlag],
        from principal: Account,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        return try await removePermissions(flags, account: account, from: principal, feeAccount: feeAccount)
    }
    
    @discardableResult
    public func removePermissions(
        _ flags: [Permission.BaseFlag],
        from principalPubKey: String,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        guard let account else { throw KeetaClientError.missingAccount }
        let principal = try AccountBuilder.create(fromPublicKey: principalPubKey)
        return try await removePermissions(flags, account: account, from: principal, feeAccount: feeAccount)
    }
    
    @discardableResult
    public func removePermissions(
        _ flags: [Permission.BaseFlag],
        account: Account,
        from principalPubKey: String,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        let principal = try AccountBuilder.create(fromPublicKey: principalPubKey)
        return try await removePermissions(flags, account: account, from: principal, feeAccount: feeAccount)
    }
    
    @discardableResult
    public func removePermissions(
        _ flags: [Permission.BaseFlag],
        account: Account,
        from principal: Account,
        feeAccount: Account? = nil
    ) async throws -> PublishResult {
        let modifyPermission = ModifyPermissionsOperation(
            principal: principal,
            method: .subtract,
            permission: Permission(baseFlags: flags)
        )
        
        let accountHeadblock = try await api.balance(for: account).currentHeadBlock

        let modifyBlock = try BlockBuilder()
            .start(from: accountHeadblock, network: config.network.id)
            .add(account: account)
            .add(operation: modifyPermission)
            .seal()
        
        return try await api.publish(blocks: [modifyBlock], feeAccount: feeAccount ?? self.feeAccount ?? account)
    }
    
    // MARK: Helper
    
    private func blockBuilder() -> BlockBuilder {
        .init(version: version)
    }
}
