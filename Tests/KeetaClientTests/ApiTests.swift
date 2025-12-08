import XCTest
import KeetaClient
import BigInt

class ApiTests: XCTestCase {
    
    var config: NetworkConfig!
    
    let wellFundedAccountSeed = "fd2bb78b1ba8b4d4b0ea6887c1725929f075e9cdfe065d07bc7070815bd87cff"
    var wellFundedAccount: Account!
    
    override func setUp() async throws {
        config = try .create(for: .test)
        wellFundedAccount = try AccountBuilder.create(fromSeed: wellFundedAccountSeed, index: 12)
        print(wellFundedAccount.publicKeyString)
        
        // Try to recover well funded account if needed
        do {
            _ = try await KeetaClient(config: config).recoverAccount(wellFundedAccount)
        } catch {
            print("⚠️ Test setup account recovery error: \(error)")
        }
    }
    
    func test_api_getBalanceOfAccountWithFunds() async throws {
        let api = try createAPI()
        
        let balance = try await api.balance(for: wellFundedAccount)
        
        XCTAssertEqual(balance.account, wellFundedAccount.publicKeyString)
        XCTAssertEqual(balance.rawBalances.count, 1, "Expected only one balance of the base token")
        XCTAssertTrue(balance.rawBalances[config.baseToken.publicKeyString, default: 0] > 0)
    }
    
    func test_recoverAccounts() async throws {
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
            let send = try SendOperation(amount: BigInt(1), to: newRecipient, token: config.baseToken)
            let senderBalance = try await api.balance(for: newAccount)
            XCTAssertNil(senderBalance.currentHeadBlock)
            
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
                XCTFail("Shouldn't receive votes for a conflicting \(version) block")
                return
            } catch RequestError<KeetaErrorResponse>.error(_, let error) {
                XCTAssertEqual(error.type, .ledger)
                XCTAssertEqual(error.code, .successorVoteExists)
            } catch {
                XCTFail("Unknown error: \(error)")
            }
            
            // Recover temporary votes
            let recoveredTemporaryVotes = try await api.recoverVotes(for: newAccount)
            XCTAssertEqual(Set(temporaryVotes.map(\.id)), Set(recoveredTemporaryVotes.map(\.id)))
            XCTAssertTrue(recoveredTemporaryVotes.allSatisfy { !$0.permanent })
            
            // Pay fees if needed
            let blocksToPublish: [Block]
            let totalFees: BigInt
            if recoveredTemporaryVotes.requiresFees {
                let recoveredStaple = try VoteStaple.create(from: recoveredTemporaryVotes, blocks: [sendBlock])
                let fee = try BlockBuilder.feeBlock(
                    for: recoveredStaple, account: newAccount, network: config, previous: sendBlock.hash
                )
                blocksToPublish = [sendBlock, fee]
                totalFees = recoveredStaple.totalFees
            } else {
                blocksToPublish = [sendBlock]
                totalFees = 0
            }
            
            // Get permanent votes using recovered temporary votes
            let permanentVotes = try await api.votes(for: blocksToPublish, temporaryVotes: recoveredTemporaryVotes)
            
            // Recover permanent votes
            let recoveredTemporaryAndPermanentVotes = try await api.recoverVotes(for: newAccount)
            XCTAssertEqual(recoveredTemporaryAndPermanentVotes.count, temporaryVotes.count + permanentVotes.count)
            let recoveredPermanentVotes = recoveredTemporaryAndPermanentVotes.filter { $0.permanent }
            XCTAssertEqual(Set(permanentVotes.map(\.id)), Set(recoveredPermanentVotes.map(\.id)))
            
            // Publish pending block with recovered votes
            let staple = try VoteStaple.create(from: recoveredPermanentVotes, blocks: blocksToPublish)
            try await api.publish(voteStaple: staple)
            
            // Verify new head block
            let expectedBalance = initialBalance - (send.amount + totalFees)
            try await api.verify(account: newAccount, head: blocksToPublish.last?.hash, balance: expectedBalance)
        }
    }
    
    func test_noPendingBlockToRecover() async throws {
        let api = try createAPI()
        let recoveredVotes = try await api.recoverVotes(for: wellFundedAccount)
        XCTAssertTrue(recoveredVotes.isEmpty, "There shouldn't be any votes to recover: \(recoveredVotes)")
    }
    
    func test_api_publishManually() async throws {
        let api = try createAPI()
        
        let newRecipient = try AccountBuilder.new()
        try await api.verify(account: newRecipient, head: nil, balance: nil)
        
        let send = try SendOperation(amount: BigInt(1), to: newRecipient, token: config.baseToken)
        
        let senderBalance = try await api.balance(for: wellFundedAccount)
        
        let sendBlock = try BlockBuilder()
            .start(from: senderBalance.currentHeadBlock, network: config.network.id)
            .add(account: wellFundedAccount)
            .add(operation: send)
            .seal()
        
        let temporaryVotes = try await api.votes(for: [sendBlock])
        XCTAssertEqual(temporaryVotes.count, config.reps.count, "Expected one temporary vote from each rep")
        XCTAssertTrue(temporaryVotes.allSatisfy { !$0.permanent }, "Expected all votes to be temporary:\n\(temporaryVotes)")
        
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
        XCTAssertEqual(permanentVotes.count, config.reps.count, "Expected one permanent vote from each rep")
        XCTAssertTrue(permanentVotes.allSatisfy { $0.permanent }, "Expected all votes to be permanent:\n\(permanentVotes)")
        
        let voteStaple = try VoteStaple.create(from: permanentVotes, blocks: blocksToPublish)
        try await api.publish(voteStaple: voteStaple)
        
        // Verify recipient's balance is updated
        try await api.verify(account: newRecipient, head: nil, balance: .init(1))
    }
    
    func test_updateReps() async throws {
        let api = try createAPI()
        try await api.updateRepresentatives()
        
        api.reps.forEach {
            XCTAssertNotNil($0.weight, "Expected rep \($0.address) to have weight")
        }
        
        let preferredRep = try XCTUnwrap(api.preferredRep)
        let otherReps = api.reps.filter { $0.address != preferredRep.address }
        
        let highestWeight = try XCTUnwrap(preferredRep.weight)
        XCTAssertTrue(otherReps.allSatisfy { ($0.weight ?? 0) <= highestWeight })
    }
    
    func test_history() async throws {
        let api = try createAPI()
        let history = try await api.history(of: wellFundedAccount)
        XCTAssertFalse(history.isEmpty)
    }
    
    func test_idempotentBlocks() async throws {
        let api = try createAPI()
        
        for version in Block.Version.all {
            let sender = try AccountBuilder.new()
            let receiver = try AccountBuilder.new()
            
            // Fund sender
            try await api.send(amount: 1_000_000, from: wellFundedAccount, to: sender, config: config)
            
            let idempotentKey = BlockBuilder.idempotentKey()
            
            let send1 = try SendOperation(amount: BigInt(1), to: receiver, token: config.baseToken)
            let sendBlock1 = try BlockBuilder(version: version)
                .start(from: nil, network: config.network.id)
                .add(account: sender)
                .add(operation: send1)
                .add(idempotent: idempotentKey)
                .seal()
            
            try await api.publish(blocks: [sendBlock1], feeAccount: sender)
            
            // Retrieve published block for idempotent key
            let retrievedBlock = try await api.block(for: sender, idempotent: idempotentKey)
            XCTAssertEqual(retrievedBlock.hash, sendBlock1.hash)
            
            let send2 = try SendOperation(amount: BigInt(2), to: receiver, token: config.baseToken)
            let sendBlock2 = try BlockBuilder(version: version)
                .start(from: sendBlock1.hash, network: config.network.id)
                .add(account: sender)
                .add(operation: send2)
                .add(idempotent: idempotentKey)
                .seal()
                
            // Expect to fail as idempotent key was already used
            do {
                try await api.publish(blocks: [sendBlock2], feeAccount: sender)
                XCTFail("Another block with the same idempotent key block shouldn't be allowed to publish")
            } catch KeetaApiError.noVotes(let errors) {
                let error = try XCTUnwrap(errors.first)
                
                if case RequestError<KeetaErrorResponse>.error(_, let error) = error {
                    XCTAssertEqual(error.type, .ledger)
                    XCTAssertEqual(error.code, .ledgerIdempotentKeyAlreadyExists)
                } else {
                    XCTFail("Unknown error: \(error)")
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func test_receiveBlock() async throws {
        let api = try createAPI()
        
        let account1 = try AccountBuilder.new()
        let account2 = try AccountBuilder.new()
        
        // Fund account 2
        try await api.send(amount: 900_000, from: wellFundedAccount, to: account2, config: config)
        try await api.verify(account: account2, head: nil, balance: 900_000)
        
        // Account 1 requests to receive token from account 2
        let receive = try ReceiveOperation(amount: 2, token: config.baseToken, from: account2, exact: true)
        let needToReceiveBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: account1)
            .add(operation: receive)
            .seal()
        
        // Account 2 publishes both his send block and the receive block
        let send = try SendOperation(amount: 2, to: account1, token: config.baseToken)
        let sendBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: account2)
            .add(operation: send)
            .seal()
        
        do {
            try await api.publish(blocks: [needToReceiveBlock, sendBlock], feeAccount: account2)
            XCTFail("Didn't expect this block order to be valid!")
            return
        } catch {}
        
        let result = try await api.publish(blocks: [sendBlock, needToReceiveBlock], feeAccount: account2)
        let baseTokenPubKey = config.baseToken.publicKeyString
        XCTAssertTrue(result.fees.allSatisfy({ $0.token == baseTokenPubKey }))
        XCTAssertEqual(Array(result.feeAmounts.keys), [baseTokenPubKey])
        
        // Verify balances
        try await api.verify(account: account1, head: needToReceiveBlock.hash, balance: 2)
        
        let feesPaid = result.feeAmounts.values.reduce(0) { $0 + $1 }
        try await api.verify(account: account2, head: result.feeBlockHash, balance: 900_000 - (2 + feesPaid))
    }
    
    func test_swapTokens() async throws {
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
        
        let mint = TokenAdminSupplyOperation(amount: BigInt(5), method: .add)
        let tokenMintBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: customToken)
            .add(operation: mint)
            .add(signer: accountWithCustomToken)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock], feeAccount: accountWithCustomToken)
        
        let sendCustomToken = try SendOperation(amount: mint.amount, to: accountWithCustomToken, token: customToken)
        let tokenSendBlock = try BlockBuilder()
            .start(from: tokenMintBlock.hash, network: config.network.id)
            .add(account: customToken)
            .add(operation: sendCustomToken)
            .add(signer: accountWithCustomToken)
            .seal()
        
        var result = try await api.publish(blocks: [tokenSendBlock], feeAccount: accountWithCustomToken)
        
        // Account with custom tokens proposes a swap: 1 custom token in exchange for 2 base token
        let receive = try ReceiveOperation(amount: 2, token: config.baseToken, from: accountWithBaseToken, exact: true)
        let needToReceiveBlock = try BlockBuilder()
            .start(from: result.feeBlockHash ?? tokenCreationBlock.hash, network: config.network.id)
            .add(account: accountWithCustomToken)
            .add(operation: receive)
            .seal()
        
        let accountWithCustomTokenSend = try SendOperation(amount: 1, to: accountWithBaseToken, token: customToken)
        let accountWithCustomTokenSendBlock = try BlockBuilder()
            .start(from: needToReceiveBlock.hash, network: config.network.id)
            .add(account: accountWithCustomToken)
            .add(operation: accountWithCustomTokenSend)
            .seal()
        
        let accountWithBaseTokenSend = try SendOperation(amount: 2, to: accountWithCustomToken, token: config.baseToken)
        let accountWithBaseTokenSendBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: accountWithBaseToken)
            .add(operation: accountWithBaseTokenSend)
            .seal()
        
        let blocks = [accountWithBaseTokenSendBlock, needToReceiveBlock, accountWithCustomTokenSendBlock]
        result = try await api.publish(blocks: blocks, feeAccount: accountWithCustomToken)
        
        // Verify balances
        let accountWithBaseTokenBalance = try await api.balance(for: accountWithBaseToken)
        XCTAssertEqual(accountWithBaseTokenBalance.rawBalances.count, 2, "\(accountWithBaseTokenBalance)")
        XCTAssertEqual(accountWithBaseTokenBalance.rawBalances[config.baseToken.publicKeyString], account1InitialBalance - accountWithBaseTokenSend.amount)
        XCTAssertEqual(accountWithBaseTokenBalance.rawBalances[customToken.publicKeyString], accountWithCustomTokenSend.amount)
        XCTAssertEqual(accountWithBaseTokenBalance.currentHeadBlock, accountWithBaseTokenSendBlock.hash)
        
        let accountWithCustomTokenBalance = try await api.balance(for: accountWithCustomToken)
        XCTAssertEqual(accountWithCustomTokenBalance.rawBalances.count, 2, "\(accountWithCustomTokenBalance)")
        
        let baseBalanceRaw = try XCTUnwrap(accountWithCustomTokenBalance.rawBalances[config.baseToken.publicKeyString])
        XCTAssertTrue(baseBalanceRaw < 100_000)
        XCTAssertEqual(accountWithCustomTokenBalance.rawBalances[customToken.publicKeyString], mint.amount - accountWithCustomTokenSend.amount)
        XCTAssertEqual(accountWithCustomTokenBalance.currentHeadBlock, result.feeBlockHash ?? accountWithCustomTokenSendBlock.hash)
    }
    
    func test_AccountInfo() async throws {
        let api = try createAPI()
        
        let newAccount = try AccountBuilder.new()

        // Fund account to pay network fee
        try await api.send(amount: 900_000, from: wellFundedAccount, to: newAccount, config: config)

        var accountInfo = try await api.accountInfo(for: newAccount)
        XCTAssertTrue(accountInfo.name.isEmpty)
        XCTAssertTrue(accountInfo.description.isEmpty)
        XCTAssertTrue(accountInfo.metadata.isEmpty)
        XCTAssertNil(accountInfo.supply)
        
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
        XCTAssertEqual(accountInfo.name, setInfo.name)
        XCTAssertEqual(accountInfo.description, setInfo.description)
        XCTAssertEqual(accountInfo.metadata, setInfo.metaData)
        XCTAssertNil(accountInfo.supply)
    }
    
    func test_voteQuotes() async throws {
        let api = try createAPI()
        
        // Fund new account
        let account = try AccountBuilder.new()
        try await api.send(amount: 1_000_000, from: wellFundedAccount, to: account, config: config)
        
        // New recipient
        let recipient = try AccountBuilder.new()
        
        let send = try SendOperation(amount: BigInt(10), to: recipient, token: config.baseToken)
        
        let sendBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: account)
            .add(operation: send)
            .seal()
        
        let quotes = try await api.voteQuotes(for: [sendBlock])
        let tempVotes = try await api.votes(for: [sendBlock], type: .temporary(quotes: quotes))
        
        // Expects quotes and fees are matching
        XCTAssertEqual(
            Set(tempVotes.fees.map { $0.payTo?.publicKeyString }),
            Set(quotes.map { $0.fee.payTo?.publicKeyString })
        )
        XCTAssertEqual(
            tempVotes.fees.map { $0.amount },
            quotes.map { $0.fee.amount }
        )
    }
    
    func test_createToken() async throws {
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
        
        let mint = TokenAdminSupplyOperation(amount: BigInt(50), method: .add)
        let info = SetInfoOperation(name: "TEST", description: Date().readable(), defaultPermission: .init(baseFlag: .ACCESS))
        let tokenMintBlock = try BlockBuilder()
            .start(from: nil, network: config.network.id)
            .add(account: newToken)
            .add(operations: mint, info)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock], feeAccount: tokenOwner)
        
        var tokenBalance = try await api.balance(for: newToken)
        XCTAssertEqual(tokenBalance.rawBalances.count, 1)
        XCTAssertEqual(tokenBalance.rawBalances[newToken.publicKeyString], mint.amount)
        XCTAssertEqual(tokenBalance.currentHeadBlock, tokenMintBlock.hash)
        
        // Burn some of the token supply
        let burn = TokenAdminSupplyOperation(amount: BigInt(10), method: .subtract)
        let tokenBurnBlock = try BlockBuilder()
            .start(from: tokenMintBlock.hash, network: config.network.id)
            .add(account: newToken)
            .add(operation: burn)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenBurnBlock], feeAccount: tokenOwner)
        
        tokenBalance = try await api.balance(for: newToken)
        XCTAssertEqual(tokenBalance.rawBalances.count, 1)
        XCTAssertEqual(tokenBalance.rawBalances[newToken.publicKeyString], mint.amount - burn.amount)
        XCTAssertEqual(tokenBalance.currentHeadBlock, tokenBurnBlock.hash)
        
        // Send token
        let recipient = try AccountBuilder.new()
        let send = try SendOperation(amount: BigInt(5), to: recipient, token: newToken)
        
        let tokenSendBlock = try BlockBuilder()
            .start(from: tokenBurnBlock.hash, network: config.network.id)
            .add(account: newToken)
            .add(operation: send)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenSendBlock], feeAccount: tokenOwner)
        
        tokenBalance = try await api.balance(for: newToken)
        XCTAssertEqual(tokenBalance.rawBalances.count, 1)
        XCTAssertEqual(tokenBalance.rawBalances[newToken.publicKeyString], mint.amount - burn.amount - send.amount)
        XCTAssertEqual(tokenBalance.currentHeadBlock, tokenSendBlock.hash)
        
        let recipientBalance = try await api.balance(for: recipient)
        XCTAssertEqual(recipientBalance.rawBalances.count, 1)
        XCTAssertEqual(recipientBalance.rawBalances[newToken.publicKeyString], send.amount)
        XCTAssertNil(recipientBalance.currentHeadBlock)
        
        // Add additional tokens to recipient to cover network fees
        try await api.send(amount: 900_000, from: wellFundedAccount, to: recipient, config: config)
        
        // Recipient returns some tokens
        let sendReturn = try SendOperation(amount: BigInt(2), to: tokenOwner, token: newToken)
        
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
