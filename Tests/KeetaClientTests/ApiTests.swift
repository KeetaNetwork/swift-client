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
    }
    
    func test_api_getBalanceOfAccountWithFunds() async throws {
        let api = try createAPI()
        
        let balance = try await api.balance(for: wellFundedAccount)
        
        XCTAssertEqual(balance.account, wellFundedAccount.publicKeyString)
        XCTAssertEqual(balance.balances.count, 1, "Expected only one balance of the base token")
        XCTAssertTrue(balance.balances[config.baseToken.publicKeyString, default: 0] > 0)
    }
    
    func test_recoverAccount() async throws {
        let api = try createAPI()
        
        // Get temporary votes
        let newRecipient = try AccountBuilder.new()
        try await api.verify(account: newRecipient, head: nil, balance: nil)
        
        let send = try SendOperation(amount: BigInt(1), to: newRecipient, token: config.baseToken)
        let senderBalance = try await api.balance(for: wellFundedAccount)
        
        let sendBlock = try BlockBuilder()
            .start(from: senderBalance.currentHeadBlock, network: config.networkID)
            .add(account: wellFundedAccount)
            .add(operation: send)
            .seal()
        
        let temporaryVotes = try await api.votes(for: [sendBlock])
        
        // Try to get new temporary votes for a different block
        let anotherSendBlock = try BlockBuilder()
            .start(from: senderBalance.currentHeadBlock, network: config.networkID)
            .add(account: wellFundedAccount)
            .add(operation: send)
            .seal()
        
        do {
            _ = try await api.votes(for: [anotherSendBlock])
            XCTFail("Shouldn't receive votes for a conflicting block")
            return
        } catch RequestError<KeetaErrorResponse>.error(_, let error) {
            XCTAssertEqual(error.type, .ledger)
            XCTAssertEqual(error.code, .successorVoteExists)
        } catch {
            XCTFail("Unknown error: \(error)")
        }
        
        // Recover temporary votes
        let recoveredTemporaryVotes = try await api.recoverVotes(for: wellFundedAccount)
        XCTAssertEqual(Set(temporaryVotes.map(\.id)), Set(recoveredTemporaryVotes.map(\.id)))
        XCTAssertTrue(recoveredTemporaryVotes.allSatisfy { !$0.permanent })
        
        // Get permanent votes using recovered temporary votes
        let permanentVotes = try await api.votes(for: [sendBlock], temporaryVotes: recoveredTemporaryVotes)
        
        // Recover permanent votes
        let recoveredTemporaryAndPermanentVotes = try await api.recoverVotes(for: wellFundedAccount)
        XCTAssertEqual(recoveredTemporaryAndPermanentVotes.count, temporaryVotes.count + permanentVotes.count)
        let recoveredPermanentVotes = recoveredTemporaryAndPermanentVotes.filter { $0.permanent }
        XCTAssertEqual(Set(permanentVotes.map(\.id)), Set(recoveredPermanentVotes.map(\.id)))
        
        // Publish pending block with recovered votes
        let staple = try VoteStaple.create(from: recoveredPermanentVotes, blocks: [sendBlock])
        try await api.publish(voteStaple: staple)
        
        // Verify new head block
        try await api.verify(account: wellFundedAccount, head: sendBlock.hash)
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
            .start(from: senderBalance.currentHeadBlock, network: config.networkID)
            .add(account: wellFundedAccount)
            .add(operation: send)
            .seal()
        
        let temporaryVotes = try await api.votes(for: [sendBlock])
        XCTAssertEqual(temporaryVotes.count, config.reps.count, "Expected one temporary vote from each rep")
        XCTAssertTrue(temporaryVotes.allSatisfy { !$0.permanent }, "Expected all votes to be temporary:\n\(temporaryVotes)")
        
        let permanentVotes = try await api.votes(for: [sendBlock], temporaryVotes: temporaryVotes)
        XCTAssertEqual(permanentVotes.count, config.reps.count, "Expected one permanent vote from each rep")
        XCTAssertTrue(permanentVotes.allSatisfy { $0.permanent }, "Expected all votes to be permanent:\n\(permanentVotes)")
        
        let voteStaple = try VoteStaple.create(from: permanentVotes, blocks: [sendBlock])
        try await api.publish(voteStaple: voteStaple)
        
        // Verify recipient's balance is updated
        try await api.verify(account: newRecipient, head: nil, balance: .init(1))
    }
    
    func test_api_publishWithAid() async throws {
        let api = try createAPI()
        
        let newRecipient = try AccountBuilder.new()
        try await api.verify(account: newRecipient, head: nil, balance: nil)

        let send = try SendOperation(amount: BigInt(2), to: newRecipient, token: config.baseToken)

        let senderBalance = try await createAPI().balance(for: wellFundedAccount)
        let sendBlock = try BlockBuilder()
            .start(from: senderBalance.currentHeadBlock, network: config.networkID)
            .add(account: wellFundedAccount)
            .add(operation: send)
            .seal()
        
        try await api.publish(blocks: [sendBlock], networkAlias: config.networkAlias, usePublishAid: true)
        
        // Verify recipient's balance is updated
        try await api.verify(account: newRecipient, head: nil, balance: .init(2))
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
    
    func test_receiveBlock() async throws {
        let api = try createAPI()
        
        let account1 = try AccountBuilder.new()
        let account2 = try AccountBuilder.new()
        
        // Fund account 2
        try await api.send(amount: 3, from: wellFundedAccount, to: account2, config: config)
        try await api.verify(account: account2, head: nil, balance: 3)
        
        // Account 1 requests to receive token from account 2
        let receive = try ReceiveOperation(amount: 2, token: config.baseToken, from: account2, exact: true)
        let needToReceiveBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: account1)
            .add(operation: receive)
            .seal()
        
        let send = try SendOperation(amount: 2, to: account1, token: config.baseToken)
        let sendBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: account2)
            .add(operation: send)
            .seal()
        
        do {
            try await api.publish(blocks: [needToReceiveBlock, sendBlock], networkAlias: config.networkAlias)
            XCTFail("Didn't expect this block order to be valid!")
            return
        } catch {}
        
        try await api.publish(blocks: [sendBlock, needToReceiveBlock], networkAlias: config.networkAlias)
        
        // Verify balances
        try await api.verify(account: account1, head: needToReceiveBlock.hash, balance: 2)
        try await api.verify(account: account2, head: sendBlock.hash, balance: 1)
    }
    
    func test_swapTokens() async throws {
        let api = try createAPI()
        
        // Fund account 1 with base token
        let accountWithBaseToken = try AccountBuilder.new()
        let account1InitialBalance = BigInt(3)
        try await api.send(amount: account1InitialBalance, from: wellFundedAccount, to: accountWithBaseToken, config: config)
        try await api.verify(account: accountWithBaseToken, head: nil, balance: account1InitialBalance)
        
        // Fund account 2 with new custom token
        let accountWithCustomToken = try AccountBuilder.new()
        let customToken = try accountWithCustomToken.generateIdentifier()
        
        let create = CreateIdentifierOperation(identifier: customToken)
        let tokenCreationBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: accountWithCustomToken)
            .add(operation: create)
            .seal()
        
        let mint = TokenAdminSupplyOperation(amount: BigInt(5), method: .add)
        let tokenMintBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: customToken)
            .add(operation: mint)
            .add(signer: accountWithCustomToken)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock], networkAlias: config.networkAlias)
        
        let sendCustomToken = try SendOperation(amount: mint.amount, to: accountWithCustomToken, token: customToken)
        let tokenSendBlock = try BlockBuilder()
            .start(from: tokenMintBlock.hash, network: config.networkID)
            .add(account: customToken)
            .add(operation: sendCustomToken)
            .add(signer: accountWithCustomToken)
            .seal()
        
        try await api.publish(blocks: [tokenSendBlock], networkAlias: config.networkAlias)
        
        // Account with custom tokens proposes a swap: 1 custom token in exchange for 2 base token
        let receive = try ReceiveOperation(amount: 2, token: config.baseToken, from: accountWithBaseToken, exact: true)
        let needToReceiveBlock = try BlockBuilder()
            .start(from: tokenCreationBlock.hash, network: config.networkID)
            .add(account: accountWithCustomToken)
            .add(operation: receive)
            .seal()
        
        let accountWithCustomTokenSend = try SendOperation(amount: 1, to: accountWithBaseToken, token: customToken)
        let accountWithCustomTokenSendBlock = try BlockBuilder()
            .start(from: needToReceiveBlock.hash, network: config.networkID)
            .add(account: accountWithCustomToken)
            .add(operation: accountWithCustomTokenSend)
            .seal()
        
        let accountWithBaseTokenSend = try SendOperation(amount: 2, to: accountWithCustomToken, token: config.baseToken)
        let accountWithBaseTokenSendBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: accountWithBaseToken)
            .add(operation: accountWithBaseTokenSend)
            .seal()
        
        let blocks = [accountWithBaseTokenSendBlock, needToReceiveBlock, accountWithCustomTokenSendBlock]
        try await api.publish(blocks: blocks, networkAlias: config.networkAlias)
        
        // Verify balances
        let accountWithBaseTokenBalance = try await api.balance(for: accountWithBaseToken)
        XCTAssertEqual(accountWithBaseTokenBalance.balances.count, 2, "\(accountWithBaseTokenBalance)")
        XCTAssertEqual(accountWithBaseTokenBalance.balances[config.baseToken.publicKeyString], account1InitialBalance - accountWithBaseTokenSend.amount)
        XCTAssertEqual(accountWithBaseTokenBalance.balances[customToken.publicKeyString], accountWithCustomTokenSend.amount)
        XCTAssertEqual(accountWithBaseTokenBalance.currentHeadBlock, accountWithBaseTokenSendBlock.hash)
        
        let accountWithCustomTokenBalance = try await api.balance(for: accountWithCustomToken)
        XCTAssertEqual(accountWithCustomTokenBalance.balances.count, 2, "\(accountWithCustomTokenBalance)")
        XCTAssertEqual(accountWithCustomTokenBalance.balances[config.baseToken.publicKeyString], receive.amount)
        XCTAssertEqual(accountWithCustomTokenBalance.balances[customToken.publicKeyString], mint.amount - accountWithCustomTokenSend.amount)
        XCTAssertEqual(accountWithCustomTokenBalance.currentHeadBlock, accountWithCustomTokenSendBlock.hash)
    }
    
    func test_AccountInfo() async throws {
        let api = try createAPI()
        
        let newAccount = try AccountBuilder.new()
        
        var accountInfo = try await api.accountInfo(for: newAccount)
        XCTAssertTrue(accountInfo.name.isEmpty)
        XCTAssertTrue(accountInfo.description.isEmpty)
        XCTAssertTrue(accountInfo.metadata.isEmpty)
        XCTAssertNil(accountInfo.supply)
        
        let setInfo = SetInfoOperation(
            name: "account_info_\(String.randomLetter())\(String.randomLetter())\(String.randomLetter())".uppercased(),
            description: "swift-core test",
            metaData: Date().readable()
        )
        
        let setInfoBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: newAccount)
            .add(operations: setInfo)
            .seal()
        
        try await api.publish(blocks: [setInfoBlock], networkAlias: config.networkAlias)
        
        accountInfo = try await api.accountInfo(for: newAccount)
        XCTAssertEqual(accountInfo.name, setInfo.name)
        XCTAssertEqual(accountInfo.description, setInfo.description)
        XCTAssertEqual(accountInfo.metadata, setInfo.metaData)
        XCTAssertNil(accountInfo.supply)
    }
    
    func test_createToken() async throws {
        let api = try createAPI()
        
        let tokenOwner = try AccountBuilder.new()
        let newToken = try tokenOwner.generateIdentifier()
        
        let create = CreateIdentifierOperation(identifier: newToken)
        let tokenCreationBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: tokenOwner)
            .add(operation: create)
            .seal()
        
        let mint = TokenAdminSupplyOperation(amount: BigInt(50), method: .add)
        let info = SetInfoOperation(name: "TEST", description: Date().readable(), defaultPermission: .init(baseFlag: .ACCESS))
        let tokenMintBlock = try BlockBuilder()
            .start(from: nil, network: config.networkID)
            .add(account: newToken)
            .add(operations: mint, info)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenCreationBlock, tokenMintBlock], networkAlias: config.networkAlias)
        
        var tokenBalance = try await api.balance(for: newToken)
        XCTAssertEqual(tokenBalance.balances.count, 1)
        XCTAssertEqual(tokenBalance.balances[newToken.publicKeyString], mint.amount)
        XCTAssertEqual(tokenBalance.currentHeadBlock, tokenMintBlock.hash)
        
        // Burn some of the token supply
        let burn = TokenAdminSupplyOperation(amount: BigInt(10), method: .subtract)
        let tokenBurnBlock = try BlockBuilder()
            .start(from: tokenMintBlock.hash, network: config.networkID)
            .add(account: newToken)
            .add(operation: burn)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenBurnBlock], networkAlias: config.networkAlias)
        
        tokenBalance = try await api.balance(for: newToken)
        XCTAssertEqual(tokenBalance.balances.count, 1)
        XCTAssertEqual(tokenBalance.balances[newToken.publicKeyString], mint.amount - burn.amount)
        XCTAssertEqual(tokenBalance.currentHeadBlock, tokenBurnBlock.hash)
        
        // Send token
        let recipient = try AccountBuilder.new()
        let send = try SendOperation(amount: BigInt(5), to: recipient, token: newToken)
        
        let tokenSendBlock = try BlockBuilder()
            .start(from: tokenBurnBlock.hash, network: config.networkID)
            .add(account: newToken)
            .add(operation: send)
            .add(signer: tokenOwner)
            .seal()
        
        try await api.publish(blocks: [tokenSendBlock], networkAlias: config.networkAlias)
        
        tokenBalance = try await api.balance(for: newToken)
        XCTAssertEqual(tokenBalance.balances.count, 1)
        XCTAssertEqual(tokenBalance.balances[newToken.publicKeyString], mint.amount - burn.amount - send.amount)
        XCTAssertEqual(tokenBalance.currentHeadBlock, tokenSendBlock.hash)
        
        let recipientBalance = try await api.balance(for: recipient)
        XCTAssertEqual(recipientBalance.balances.count, 1)
        XCTAssertEqual(recipientBalance.balances[newToken.publicKeyString], send.amount)
        XCTAssertNil(recipientBalance.currentHeadBlock)
        
        // Recipient returns some tokens
        let sendReturn = try SendOperation(amount: BigInt(2), to: tokenOwner, token: newToken)
        
        let returnTokensBlock = try BlockBuilder()
            .start(from: recipientBalance.currentHeadBlock, network: config.networkID)
            .add(account: recipient)
            .add(operation: sendReturn)
            .seal()
     
        try await api.publish(blocks: [returnTokensBlock], networkAlias: config.networkAlias)
    }
    
    // MARK: - Helper

    func createAPI() throws -> KeetaApi {
        try KeetaApi(publishAidUrl: config.publishAidUrl, reps: config.reps)
    }
}
