import Foundation
import Testing
import KeetaClient
import BigInt

@Suite(.serialized) struct ApiTests {
    
    let config: NetworkConfig
    let wellFundedAccount: Account
    
    private static let wellFundedAccountSeed = "fd2bb78b1ba8b4d4b0ea6887c1725929f075e9cdfe065d07bc7070815bd87cff"
    
    init() async throws {
        config = try .create(for: .test)
        wellFundedAccount = try AccountBuilder.create(fromSeed: Self.wellFundedAccountSeed, index: 14)
        print(wellFundedAccount.publicKeyString)
        
        // Try to recover well funded account if needed
        do {
            _ = try await KeetaClient(config: config).recoverAccount(wellFundedAccount)
        } catch {
            print("⚠️ Test setup account recovery error: \(error)")
        }
    }
    
    @Test func api_getBalanceOfAccountWithFunds() async throws {
        let api = try createAPI()
        
        let balance = try await api.balance(for: wellFundedAccount)
        
        #expect(balance.account == wellFundedAccount.publicKeyString)
        #expect(balance.rawBalances.count == 1, "Expected only one balance of the base token")
        #expect(balance.rawBalances[config.baseToken.publicKeyString, default: 0] > 0)
    }
    
    @Test func fetchCertificates() async throws {
        let api = try createAPI()
        
        let account = try AccountBuilder.create(
            fromPublicKey: "keeta_aabg2lkwuy4gvzr44cniihdmwzinfuunqv4qgsuhbq7jpt4qms622tldjbdexwy"
        )
        let fetchedAll = try await api.certificates(for: account)
        #expect(fetchedAll.count >= 20)
        
        let first = try #require(fetchedAll.first)
        let fetchedSpecific = try await api.certificate(for: account, hash: first.hash)
        
        #expect(first == fetchedSpecific)
    }
    
    @Test func modifyCertificates() async throws {
        let api = try createAPI()
        
        let seed = "5fb3a1e05f46b8ea4dc56b95f575229586b225a335d8d06f723e544dac5bdc64"
        let certAccount = try AccountBuilder.create(fromSeed: seed, index: 0)
        
        // Fund sender
        try await api.send(amount: 800_000, from: wellFundedAccount, to: certAccount, config: config)
        
        // Add certificate for account 'keeta_aabx2vtqjhfzjm7vmn2jtqdhzx36brozcrs5ovmo2wo5lrdafzw7cmoq23djbzq'
        let localCertificate = try Certificate.create(from: """
            -----BEGIN CERTIFICATE-----
                MIIB0DCCAXagAwIBAgIBATALBglghkgBZQMEAwowUDFOMEwGA1UEAxZFa2VldGFf
                YWFieDJ2dHFqaGZ6am03dm1uMmp0cWRoengzNmJyb3pjcnM1b3ZtbzJ3bzVscmRh
                Znp3N2Ntb3EyM2RqYnpxMB4XDTI0MTEwMTE2MDQ0M1oXDTI0MTEwMjE2MDQ0M1ow
                UDFOMEwGA1UEAxZFa2VldGFfYWFieDJ2dHFqaGZ6am03dm1uMmp0cWRoengzNmJy
                b3pjcnM1b3ZtbzJ3bzVscmRhZnp3N2Ntb3EyM2RqYnpxMDYwEAYHKoZIzj0CAQYF
                K4EEAAoDIgADfVZwScuUs/VjdJnAZ8334MXZFGXXVY7VndXEYC5t8TGjYzBhMA8G
                A1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgDGMB8GA1UdIwQYMBaAFF8a+R9T
                IDOFQDslLk8zwia8nyIHMB0GA1UdDgQWBBRfGvkfUyAzhUA7JS5PM8ImvJ8iBzAL
                BglghkgBZQMEAwoDRwAwRAIgfNPiPH6neCaq7nmqvW5cq3D/LptuSyGA36Q4nnQp
                LsICICsHBxM+W6mtJR9LIUNfyuJrVh6k//ZxwfT2GtbaofGS
                -----END CERTIFICATE-----
            """)
        
        let addOperation = ModifyCertificateOperation(operation: .add(localCertificate))
        
        let blockHead = try await api.balance(for: certAccount).currentHeadBlock
        
        let addBlock = try BlockBuilder()
            .start(from: blockHead, network: config.network.id)
            .add(account: certAccount)
            .add(operation: addOperation)
            .seal()
        
        let addPublishResult = try await api.publish(blocks: [addBlock], feeAccount: certAccount)
        
        // Fetch certificate from chain
        var allCertificates = try await api.certificates(for: certAccount)
        
        #expect(allCertificates.count == 1)
        let fetchedCertificate = try #require(allCertificates.first)
        #expect(fetchedCertificate == localCertificate)
        
        // Remove certificate from account
        let removeOperation = ModifyCertificateOperation(operation: .remove(hash: fetchedCertificate.hash))
        
        let removeBlock = try BlockBuilder()
            .start(from: addPublishResult.lastBlockHash(for: certAccount), network: config.network.id)
            .add(account: certAccount)
            .add(operation: removeOperation)
            .seal()
        
        try await api.publish(blocks: [removeBlock], feeAccount: certAccount)
        
        allCertificates = try await api.certificates(for: certAccount)
        #expect(allCertificates == [])
    }
    
    @Test func recoverAccounts() async throws {
        for version in Block.Version.all {
            let api = try createAPI()
            
            // Fund new account, enough to cover rep fees
            let newAccount = try AccountBuilder.new()
            let initialBalance: BigInt = 50_000_000
            try await api.send(amount: initialBalance, from: wellFundedAccount, to: newAccount, config: config)
            try await api.verify(account: newAccount, head: nil, balance: initialBalance)
            
            // Create new recipient
            let newRecipient = try AccountBuilder.new()
            try await api.verify(account: newRecipient, head: nil, balance: nil)
            
            // Get temporary votes for send block
            let send = try SendOperation(amount: TokenAmount(raw: 1), to: newRecipient, token: config.baseToken)
            let senderBalance = try await api.balance(for: newAccount)
            #expect(senderBalance.currentHeadBlock == nil)
            
            let sendBlock = try BlockBuilder(version: version)
                .start(from: senderBalance.currentHeadBlock, network: config.network.id)
                .add(account: newAccount)
                .add(operation: send)
                .seal()
            
            let temporaryVotes = try await api.votes(for: [sendBlock])
            
            // Try to get new temporary votes for a different block
            let anotherSendBlock = try BlockBuilder(version: version)
                .start(from: senderBalance.currentHeadBlock, network: config.network.id)
                .add(account: newAccount)
                .add(operation: send)
                .seal()
            
            do {
                _ = try await api.votes(for: [anotherSendBlock])
                Issue.record("Shouldn't receive votes for a conflicting \(version) block")
                return
            } catch RequestError<KeetaErrorResponse>.error(_, let error) {
                #expect(error.type == .ledger)
                #expect(error.code == .successorVoteExists)
            } catch {
                Issue.record("Unknown error: \(error)")
            }
            
            // Recover temporary votes
            let recoveredTemporaryVotes = try await api.recoverVotes(for: newAccount)
            #expect(Set(temporaryVotes.map(\.id)) == Set(recoveredTemporaryVotes.map(\.id)))
            #expect(recoveredTemporaryVotes.allSatisfy { !$0.permanent })
            
            // Pay fees if needed
            let blocksToPublish: [Block]
            let totalFees: BigInt
            if recoveredTemporaryVotes.requiresFees {
                let recoveredStaple = try VoteStaple.create(from: recoveredTemporaryVotes, blocks: [sendBlock])
                let fee = try BlockBuilder.feeBlock(
                    for: recoveredStaple, account: newAccount, network: config, previous: sendBlock.hash
                )
                blocksToPublish = [sendBlock, fee]
                totalFees = recoveredStaple.totalFees(baseToken: config.baseToken, supportedByAllVotes: true)[config.baseToken.publicKeyString] ?? 0
            } else {
                blocksToPublish = [sendBlock]
                totalFees = 0
            }
            
            // Get permanent votes using recovered temporary votes
            let permanentVotes = try await api.votes(for: blocksToPublish, temporaryVotes: recoveredTemporaryVotes)
            
            // Recover permanent votes
            let recoveredTemporaryAndPermanentVotes = try await api.recoverVotes(for: newAccount)
            #expect(recoveredTemporaryAndPermanentVotes.count == temporaryVotes.count + permanentVotes.count)
            let recoveredPermanentVotes = recoveredTemporaryAndPermanentVotes.filter { $0.permanent }
            #expect(Set(permanentVotes.map(\.id)) == Set(recoveredPermanentVotes.map(\.id)))
            
            // Publish pending block with recovered votes
            let staple = try VoteStaple.create(from: recoveredPermanentVotes, blocks: blocksToPublish)
            try await api.publish(voteStaple: staple)
            
            // Verify new head block
            let expectedBalance = initialBalance - (send.amount + totalFees)
            try await api.verify(account: newAccount, head: blocksToPublish.last?.hash, balance: expectedBalance)
        }
    }
    
    @Test func noPendingBlockToRecover() async throws {
        let api = try createAPI()
        let recoveredVotes = try await api.recoverVotes(for: wellFundedAccount)
        #expect(recoveredVotes.isEmpty, "There shouldn't be any votes to recover: \(recoveredVotes)")
    }
    
    @Test func api_publishManually() async throws {
        let api = try createAPI()
        
        let newRecipient = try AccountBuilder.new()
        try await api.verify(account: newRecipient, head: nil, balance: nil)
        
        let send = try SendOperation(amount: TokenAmount(raw: 1), to: newRecipient, token: config.baseToken)
        
        let senderBalance = try await api.balance(for: wellFundedAccount)
        
        let sendBlock = try BlockBuilder()
            .start(from: senderBalance.currentHeadBlock, network: config.network.id)
            .add(account: wellFundedAccount)
            .add(operation: send)
            .seal()
        
        let temporaryVotes = try await api.votes(for: [sendBlock])
        #expect(temporaryVotes.count == config.reps.count, "Expected one temporary vote from each rep")
        #expect(temporaryVotes.allSatisfy { !$0.permanent }, "Expected all votes to be temporary:\n\(temporaryVotes)")
        
        let blocksToPublish: [Block]
        if temporaryVotes.requiresFees {
            let temporaryStaple = try VoteStaple.create(from: temporaryVotes, blocks: [sendBlock])
            let fee = try BlockBuilder.feeBlock(
                for: temporaryStaple, account: wellFundedAccount, network: config, previous: sendBlock.hash
            )
            blocksToPublish = [sendBlock, fee]
        } else {
            blocksToPublish = [sendBlock]
        }
        
        let permanentVotes = try await api.votes(for: blocksToPublish, temporaryVotes: temporaryVotes)
        #expect(permanentVotes.count == config.reps.count, "Expected one permanent vote from each rep")
        #expect(permanentVotes.allSatisfy { $0.permanent }, "Expected all votes to be permanent:\n\(permanentVotes)")
        
        let voteStaple = try VoteStaple.create(from: permanentVotes, blocks: blocksToPublish)
        try await api.publish(voteStaple: voteStaple)
        
        // Verify recipient's balance is updated
        try await api.verify(account: newRecipient, head: nil, balance: .init(1))
    }
    
    @Test func updateReps() async throws {
        let api = try createAPI()
        try await api.updateRepresentatives()
        
        api.reps.forEach {
            #expect($0.weight != nil, "Expected rep \($0.address) to have weight")
        }
        
        let preferredRep = api.preferredRep
        let otherReps = api.reps.filter { $0.address != preferredRep.address }
        
        let highestWeight = try #require(preferredRep.weight)
        #expect(otherReps.allSatisfy { ($0.weight ?? 0) <= highestWeight })
    }
    
    @Test func history() async throws {
        let api = try createAPI()
        let history = try await api.history(of: wellFundedAccount)
        #expect(!history.isEmpty)
    }
    
    @Test func idempotentBlocks() async throws {
        let api = try createAPI()
        
        for version in Block.Version.all {
            let sender = try AccountBuilder.new()
            let receiver = try AccountBuilder.new()
            
            // Fund sender
            try await api.send(amount: 1_000_000, from: wellFundedAccount, to: sender, config: config)
            
            let idempotentKey = BlockBuilder.idempotentKey()
            
            let send1 = try SendOperation(amount: TokenAmount(raw: 1), to: receiver, token: config.baseToken)
            let sendBlock1 = try BlockBuilder(version: version)
                .start(from: nil, network: config.network.id)
                .add(account: sender)
                .add(operation: send1)
                .add(idempotent: idempotentKey)
                .seal()
            
            try await api.publish(blocks: [sendBlock1], feeAccount: sender)
            
            // Retrieve published block for idempotent key
            let retrievedBlock = try await api.block(for: sender, idempotent: idempotentKey)
            #expect(retrievedBlock.hash == sendBlock1.hash)
            
            let send2 = try SendOperation(amount: TokenAmount(raw: 2), to: receiver, token: config.baseToken)
            let sendBlock2 = try BlockBuilder(version: version)
                .start(from: sendBlock1.hash, network: config.network.id)
                .add(account: sender)
                .add(operation: send2)
                .add(idempotent: idempotentKey)
                .seal()
            
            // Expect to fail as idempotent key was already used
            do {
                try await api.publish(blocks: [sendBlock2], feeAccount: sender)
                Issue.record("Another block with the same idempotent key block shouldn't be allowed to publish")
            } catch KeetaApiError.noVotes(let errors) {
                let error = try #require(errors.first)
                
                if case RequestError<KeetaErrorResponse>.error(_, let error) = error {
                    #expect(error.type == .ledger)
                    #expect(error.code == .ledgerIdempotentKeyAlreadyExists)
                } else {
                    Issue.record("Unknown error: \(error)")
                }
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }
    
    @Test func receiveBlock() async throws {
        let api = try createAPI()
        
        let account1 = try AccountBuilder.new()
        let account2 = try AccountBuilder.new()
        
        // Fund account 2
        try await api.send(amount: 900_000, from: wellFundedAccount, to: account2, config: config)
        try await api.verify(account: account2, head: nil, balance: 900_000)
        
        // Account 1 requests to receive token from account 2
        let receive = try ReceiveOperation(amount: TokenAmount(raw: 2), token: config.baseToken, from: account2, exact: true)
        let needToReceiveBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: account1)
            .add(operation: receive)
            .seal()
        
        // Account 2 publishes both his send block and the receive block
        let send = try SendOperation(amount: TokenAmount(raw: 2), to: account1, token: config.baseToken)
        let sendBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: account2)
            .add(operation: send)
            .seal()
        
        do {
            try await api.publish(blocks: [needToReceiveBlock, sendBlock], feeAccount: account2)
            Issue.record("Didn't expect this block order to be valid!")
            return
        } catch {}
        
        let result = try await api.publish(blocks: [sendBlock, needToReceiveBlock], feeAccount: account2)
        let baseTokenPubKey = config.baseToken.publicKeyString
        #expect(result.fees.allSatisfy({ $0.token == baseTokenPubKey }))
        #expect(Array(result.feeAmounts.keys) == [baseTokenPubKey])
        
        // Verify balances
        try await api.verify(account: account1, head: needToReceiveBlock.hash, balance: 2)
        
        let feesPaid = result.feeAmounts.values.reduce(0) { $0 + $1 }
        try await api.verify(account: account2, head: result.feeBlockHash, balance: 900_000 - (2 + feesPaid))
    }
    
    @Test func swapTokens() async throws {
        let api = try createAPI()
        
        // Fund account 1 with enough base token for the trade
        let accountWithBaseToken = try AccountBuilder.new()
        let account1InitialBalance = BigInt(3)
        try await api.send(amount: account1InitialBalance, from: wellFundedAccount, to: accountWithBaseToken, config: config)
        try await api.verify(account: accountWithBaseToken, head: nil, balance: account1InitialBalance)
        
        // Fund account 2 with base token to cover token creation tx fee
        let accountWithCustomToken = try AccountBuilder.new()
        try await api.send(amount: 1_500_000, from: wellFundedAccount, to: accountWithCustomToken, config: config)
        
        // Create new token and fund account 2
        let customToken = try accountWithCustomToken.generateIdentifier()
        
        let create = CreateIdentifierOperation(identifier: customToken)
        let tokenCreationBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: accountWithCustomToken)
            .add(operation: create)
            .seal()
        
        let mint = TokenAdminSupplyOperation(amount: TokenAmount(raw: 5), method: .add)
        let tokenMintBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: customToken)
            .add(operation: mint)
            .add(signer: accountWithCustomToken)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock], feeAccount: accountWithCustomToken)
        
        let sendCustomToken = try SendOperation(amount: TokenAmount(raw: mint.amount), to: accountWithCustomToken, token: customToken)
        let tokenSendBlock = try BlockBuilder()
            .start(from: tokenMintBlock.hash, network: config.network.id)
            .add(account: customToken)
            .add(operation: sendCustomToken)
            .add(signer: accountWithCustomToken)
            .seal()
        
        var result = try await api.publish(blocks: [tokenSendBlock], feeAccount: accountWithCustomToken)
        
        // Account with custom tokens proposes a swap: 1 custom token in exchange for 2 base token
        let receive = try ReceiveOperation(amount: TokenAmount(raw: 2), token: config.baseToken, from: accountWithBaseToken, exact: true)
        let needToReceiveBlock = try BlockBuilder()
            .start(from: result.feeBlockHash ?? tokenCreationBlock.hash, network: config.network.id)
            .add(account: accountWithCustomToken)
            .add(operation: receive)
            .seal()
        
        let accountWithCustomTokenSend = try SendOperation(amount: TokenAmount(raw: 1), to: accountWithBaseToken, token: customToken)
        let accountWithCustomTokenSendBlock = try BlockBuilder()
            .start(from: needToReceiveBlock.hash, network: config.network.id)
            .add(account: accountWithCustomToken)
            .add(operation: accountWithCustomTokenSend)
            .seal()
        
        let accountWithBaseTokenSend = try SendOperation(amount: TokenAmount(raw: 2), to: accountWithCustomToken, token: config.baseToken)
        let accountWithBaseTokenSendBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: accountWithBaseToken)
            .add(operation: accountWithBaseTokenSend)
            .seal()
        
        let blocks = [accountWithBaseTokenSendBlock, needToReceiveBlock, accountWithCustomTokenSendBlock]
        result = try await api.publish(blocks: blocks, feeAccount: accountWithCustomToken)
        
        // Verify balances
        let accountWithBaseTokenBalance = try await api.balance(for: accountWithBaseToken)
        #expect(accountWithBaseTokenBalance.rawBalances.count == 2, "\(accountWithBaseTokenBalance)")
        #expect(accountWithBaseTokenBalance.rawBalances[config.baseToken.publicKeyString] == account1InitialBalance - accountWithBaseTokenSend.amount)
        #expect(accountWithBaseTokenBalance.rawBalances[customToken.publicKeyString] == accountWithCustomTokenSend.amount)
        #expect(accountWithBaseTokenBalance.currentHeadBlock == accountWithBaseTokenSendBlock.hash)
        
        let accountWithCustomTokenBalance = try await api.balance(for: accountWithCustomToken)
        #expect(accountWithCustomTokenBalance.rawBalances.count == 2, "\(accountWithCustomTokenBalance)")
        
        let baseBalanceRaw = try #require(accountWithCustomTokenBalance.rawBalances[config.baseToken.publicKeyString])
        #expect(baseBalanceRaw < 100_000)
        #expect(accountWithCustomTokenBalance.rawBalances[customToken.publicKeyString] == mint.amount - accountWithCustomTokenSend.amount)
        #expect(accountWithCustomTokenBalance.currentHeadBlock == result.feeBlockHash ?? accountWithCustomTokenSendBlock.hash)
    }
    
    @Test func accountInfo() async throws {
        let api = try createAPI()
        
        let newAccount = try AccountBuilder.new()
        
        // Fund account to pay network fee
        try await api.send(amount: 900_000, from: wellFundedAccount, to: newAccount, config: config)
        
        var accountInfo = try await api.accountInfo(for: newAccount)
        #expect(accountInfo.name.isEmpty)
        #expect(accountInfo.description.isEmpty)
        #expect(accountInfo.metadata.isEmpty)
        #expect(accountInfo.supply == nil)
        
        let setInfo = SetInfoOperation(
            name: "account_info_\(String.randomLetter())\(String.randomLetter())\(String.randomLetter())".uppercased(),
            description: "swift-core test",
            metaData: Date().readable().replacingOccurrences(of: ".", with: "/")
        )
        
        let setInfoBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: newAccount)
            .add(operations: setInfo)
            .seal()
        
        try await api.publish(blocks: [setInfoBlock], feeAccount: newAccount)
        
        accountInfo = try await api.accountInfo(for: newAccount)
        #expect(accountInfo.name == setInfo.name)
        #expect(accountInfo.description == setInfo.description)
        #expect(accountInfo.metadata == setInfo.metaData)
        #expect(accountInfo.supply == nil)
    }
    
    @Test func voteQuotes() async throws {
        let api = try createAPI()
        
        // Fund new account
        let account = try AccountBuilder.new()
        try await api.send(amount: 1_000_000, from: wellFundedAccount, to: account, config: config)
        
        // New recipient
        let recipient = try AccountBuilder.new()
        
        let send = try SendOperation(amount: TokenAmount(raw: 10), to: recipient, token: config.baseToken)
        
        let sendBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: account)
            .add(operation: send)
            .seal()
        
        let quotes = try await api.voteQuotes(for: [sendBlock])
        let tempVotes = try await api.votes(for: [sendBlock], type: .temporary(quotes: quotes))
        
        // Expects quotes and fees are matching
        let votePayTos = Set(tempVotes.feeEntries.map { $0.payTo?.publicKeyString })
        let quotePayTos = Set(quotes.flatMap { $0.fee.entries }.map { $0.payTo?.publicKeyString })
        #expect(votePayTos == quotePayTos)
        
        let voteAmounts = tempVotes.feeEntries.map { $0.amount }
        let quoteAmounts = quotes.flatMap { $0.fee.entries }.map { $0.amount }
        #expect(voteAmounts == quoteAmounts)
    }
    
    @Test func modifyPermissionSendOnBehalf() async throws {
        let api = try createAPI()
        
        let owner = try AccountBuilder.new()
        let other = try AccountBuilder.new()
        
        // Retrieve granted permissions from network
        let initialGrantedPermissions = try await api.grantedPermissions(of: owner)
        #expect(initialGrantedPermissions == [])
        
        try await api.send(amount: 3_600_000, from: wellFundedAccount, to: owner, config: config)
        
        let modifyPermission = ModifyPermissionsOperation(
            principal: other,
            method: .set,
            permission: Permission(baseFlags: [.ACCESS, .SEND_ON_BEHALF])
        )
        
        let modifyBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: owner)
            .add(operation: modifyPermission)
            .seal()
        
        try await api.publish(blocks: [modifyBlock], feeAccount: owner)
        
        let history = try await api.history(of: owner)
        let modifyHistoryBlock = try #require(history.first?.blocks.first)
        
        let operation = try #require(modifyHistoryBlock.rawData.operations.first)
        let parsed = try operation.to(ModifyPermissionsOperation.self)
        
        #expect(parsed.permission == modifyPermission.permission)
        
        // Retrieve granted permissions from network
        let grantedPermissions = try await api.grantedPermissions(of: owner)
        #expect(grantedPermissions.count == 1)
        let grantedPermission = try #require(grantedPermissions.first)
        #expect(grantedPermission.principal.publicKeyString == other.publicKeyString)
        #expect(grantedPermission.target?.publicKeyString == owner.publicKeyString)
        #expect(grantedPermission.permission == modifyPermission.permission)
        
        // Retrieve received permissions from network
        let receivedPermissions = try await api.permissionsReceived(for: other)
        
        #expect(receivedPermissions.count == 1)
        let receivedPermission = try #require(receivedPermissions.first)
        #expect(receivedPermission.principal.publicKeyString == other.publicKeyString)
        #expect(receivedPermission.target?.publicKeyString == owner.publicKeyString)
        #expect(receivedPermission.permission == modifyPermission.permission)
        
        // Ensure both endpoints return the same data
        #expect(grantedPermissions == receivedPermissions)
        
        let ownerBalanceBeforeSend = try await api.balance(for: owner)
        
        // Send owner funds using the new authorized account
        let recipient = try AccountBuilder.new()
        let send = try SendOperation(amount: TokenAmount(raw: 10), to: recipient, token: config.baseToken)
        
        let ownerLastBlockHash = history.first?.blocks.last?.hash
        let sendBlock = try BlockBuilder()
            .start(from: ownerLastBlockHash, network: config.network.id)
            .add(account: owner)
            .add(operation: send)
            .add(signer: other)
            .seal()
        
        try await api.publish(blocks: [sendBlock], feeAccount: owner)
        
        // Verify balances
        let ownerBalanceAfterSend = try await api.balance(for: owner)
        #expect(
            ownerBalanceAfterSend.rawBalances[config.baseToken.publicKeyString, default: 0] + send.amount
                <= ownerBalanceBeforeSend.rawBalances[config.baseToken.publicKeyString, default: 0]
        )
        
        let recipientBalance = try await api.balance(for: recipient)
        #expect(send.amount == recipientBalance.rawBalances[config.baseToken.publicKeyString])
    }
    
    @Test func permissions() async throws {
        let api = try createAPI()
        
        let owner = try AccountBuilder.new()
        let storage = try owner.generateIdentifier(type: .STORAGE)
        
        try await api.send(amount: 3_600_000, from: wellFundedAccount, to: owner, config: config)
        
        // Publish storage account with info & base permissions
        let createBlock = try BlockBuilder()
            .start(from: nil, config: config)
            .add(account: owner)
            .add(operation: CreateIdentifierOperation(identifier: storage))
            .seal()
        
        let setupBlock = try BlockBuilder()
            .start(from: nil, config: config)
            .add(account: storage)
            .add(signer: owner)
            .add(operations:
                SetInfoOperation(
                    name: "",
                    description: "swift-core-test",
                    defaultPermission: Permission(baseFlags: [.ACCESS, .MANAGE_CERTIFICATE])
                )
            )
            .seal()
        
        let publishResult = try await api.publish(blocks: [createBlock, setupBlock], feeAccount: owner)
        
        // Verify base permissions got added
        var info = try await api.accountInfo(for: storage)
        #expect(info.defaultPermission?.baseFlags == [.ACCESS, .MANAGE_CERTIFICATE])
        #expect(info.defaultPermission?.external == .zero)
        
        // Override default base permissions to remove manage certificate
        let overrideBlock = try BlockBuilder()
            .start(from: publishResult.lastBlockHash(for: storage), config: config)
            .add(account: storage)
            .add(signer: owner)
            .add(operations:
                SetInfoOperation(
                    name: "",
                    description: "swift-core-test",
                    defaultPermission: Permission(baseFlags: [.ACCESS])
                )
            )
            .seal()
        
        try await api.publish(blocks: [overrideBlock], feeAccount: owner)
        
        // Verify permissions got reduced
        info = try await api.accountInfo(for: storage)
        #expect(info.defaultPermission?.baseFlags == [.ACCESS])
        #expect(info.defaultPermission?.external == .zero)
    }
    
    @Test func createToken() async throws {
        let api = try createAPI()
        
        // Fund token owner's account to cover token creation tx fee
        let tokenOwner = try AccountBuilder.new()
        try await api.send(amount: 1_800_000, from: wellFundedAccount, to: tokenOwner, config: config)
        
        let newToken = try tokenOwner.generateIdentifier()
        
        let create = CreateIdentifierOperation(identifier: newToken)
        let tokenCreationBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: tokenOwner)
            .add(operation: create)
            .seal()
        
        let mint = TokenAdminSupplyOperation(amount: TokenAmount(raw: 50), method: .add)
        let info = SetInfoOperation(name: "TEST", description: Date().readable(), defaultPermission: .init(baseFlags: [.ACCESS]))
        let tokenMintBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: newToken)
            .add(operations: mint, info)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock], feeAccount: tokenOwner)
        
        var tokenBalance = try await api.balance(for: newToken)
        #expect(tokenBalance.rawBalances.count == 1)
        #expect(tokenBalance.rawBalances[newToken.publicKeyString] == mint.amount)
        #expect(tokenBalance.currentHeadBlock == tokenMintBlock.hash)
        
        // Burn some of the token supply
        let burn = TokenAdminSupplyOperation(amount: TokenAmount(raw: 10), method: .subtract)
        let tokenBurnBlock = try BlockBuilder()
            .start(from: tokenMintBlock.hash, network: config.network.id)
            .add(account: newToken)
            .add(operation: burn)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenBurnBlock], feeAccount: tokenOwner)
        
        tokenBalance = try await api.balance(for: newToken)
        #expect(tokenBalance.rawBalances.count == 1)
        #expect(tokenBalance.rawBalances[newToken.publicKeyString] == mint.amount - burn.amount)
        #expect(tokenBalance.currentHeadBlock == tokenBurnBlock.hash)
        
        // Send token
        let recipient = try AccountBuilder.new()
        let send = try SendOperation(amount: TokenAmount(raw: 5), to: recipient, token: newToken)
        
        let tokenSendBlock = try BlockBuilder()
            .start(from: tokenBurnBlock.hash, network: config.network.id)
            .add(account: newToken)
            .add(operation: send)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenSendBlock], feeAccount: tokenOwner)
        
        tokenBalance = try await api.balance(for: newToken)
        #expect(tokenBalance.rawBalances.count == 1)
        #expect(tokenBalance.rawBalances[newToken.publicKeyString] == mint.amount - burn.amount - send.amount)
        #expect(tokenBalance.currentHeadBlock == tokenSendBlock.hash)
        
        let recipientBalance = try await api.balance(for: recipient)
        #expect(recipientBalance.rawBalances.count == 1)
        #expect(recipientBalance.rawBalances[newToken.publicKeyString] == send.amount)
        #expect(recipientBalance.currentHeadBlock == nil)
        
        // Add additional tokens to recipient to cover network fees
        try await api.send(amount: 900_000, from: wellFundedAccount, to: recipient, config: config)
        
        // Recipient returns some tokens
        let sendReturn = try SendOperation(amount: TokenAmount(raw: 2), to: tokenOwner, token: newToken)
        
        let returnTokensBlock = try BlockBuilder()
            .start(from: recipientBalance.currentHeadBlock, network: config.network.id)
            .add(account: recipient)
            .add(operation: sendReturn)
            .seal()
     
        try await api.publish(blocks: [returnTokensBlock], feeAccount: recipient)
    }
    
    // MARK: - Helper

    func createAPI() throws -> KeetaApi {
        try KeetaApi(config: config)
    }
}
