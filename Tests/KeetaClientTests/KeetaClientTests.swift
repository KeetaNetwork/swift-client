import XCTest
import BigInt
import KeetaClient

final class KeetaClientTests: XCTestCase {
    
    let wellFundedAccountSeed = "abf3a19b7815b5cb73084afe99420b59c908e9f3acb2c3ce1b494e3190fdf1a1"
    var wellFundedAccount: Account!
    
    override func setUp() async throws {
        wellFundedAccount = try AccountBuilder.create(fromSeed: wellFundedAccountSeed, index: 1)
        print(wellFundedAccount.publicKeyString)
    }
    
    struct ExpectedTransaction {
        let amount: BigInt
        let to: Account
        let from: Account
        let token: Account
        
        func matches(_ transaction: Transaction) -> Bool {
            transaction.amount == amount
            && transaction.to.publicKeyString == to.publicKeyString
            && transaction.from.publicKeyString == from.publicKeyString
            && transaction.token.publicKeyString == token.publicKeyString
        }
        
        func pretty() -> String {
            "amount: \(amount.readable()), from: \(from.publicKeyString), to: \(to.publicKeyString), token: \(token.publicKeyString)"
        }
    }
    
    func test_insufficientBalanceForFees() async throws {
        let newAccount = try AccountBuilder.new()
        let recipient = try AccountBuilder.new()
        
        let client = KeetaClient(network: .test, account: newAccount)
        
        // Enough funding to cover the send transaction but not the fees
        try await fund(account: newAccount, amount: 2)
        
        do {
            _ = try await client.send(amount: 1, to: recipient)
            XCTFail("Expected insufficient balance to cover fees to block this transaction")
            return
        } catch BlockBuilderError.insufficientBalanceToCoverNetworkFees {
            // expected
        } catch {
            XCTFail("Unknown error: \(error)")
        }
    }
    
    func test_transactions() async throws {
        let account1 = try AccountBuilder.new()
        let account2 = try AccountBuilder.new()
        let feeAccount = try AccountBuilder.new()
        
        // Fund fee account
        let initialFeeFunds: BigInt = 2_000_000
        try await fund(account: feeAccount, amount: initialFeeFunds)
        
        // Fund accounts
        try await fund(account: account1, amount: 11)
        try await fund(account: account2, amount: 12)
        
        let client1 = KeetaClient(network: .test, account: account1, feeAccount: feeAccount)
        try await client1.send(amount: 1, to: account2)
        
        let client2 = KeetaClient(network: .test, account: account2, feeAccount: feeAccount)
        try await client2.send(amount: 2, to: account1)
        
        let account1Transactions = try await client1.transactions()
        let account1ExpectedTransactions = [
            ExpectedTransaction(amount: 2, to: account1, from: account2, token: client1.config.baseToken),
            ExpectedTransaction(amount: 1, to: account2, from: account1, token: client1.config.baseToken),
            ExpectedTransaction(amount: 11, to: account1, from: wellFundedAccount, token: client1.config.baseToken)
        ]
        assert(account1Transactions, account1ExpectedTransactions)
        
        let account2Transactions = try await client2.transactions()
        let account2ExpectedTransactions = [
            ExpectedTransaction(amount: 2, to: account1, from: account2, token: client2.config.baseToken),
            ExpectedTransaction(amount: 1, to: account2, from: account1, token: client2.config.baseToken),
            ExpectedTransaction(amount: 12, to: account2, from: wellFundedAccount, token: client2.config.baseToken)
        ]
        assert(account2Transactions, account2ExpectedTransactions)
        
        let client = KeetaClient(network: .test)
        let feeTransactions = try await client.transactions(for: feeAccount)
        let expectedFeesPaidTransferCount = 8 // 2 blocks published with 4 reps used to reach quorum
        XCTAssertEqual(feeTransactions.count, 1 + expectedFeesPaidTransferCount) // 1 incoming fund transaction
        XCTAssertEqual(feeTransactions.count(where: { $0.amount == 110_100 }), expectedFeesPaidTransferCount)
        XCTAssertEqual(feeTransactions.count(where: { $0.isNetworkFee }), expectedFeesPaidTransferCount)
        XCTAssertEqual(feeTransactions.count(where: { $0.from.publicKeyString == feeAccount.publicKeyString }), expectedFeesPaidTransferCount)
        XCTAssertEqual(feeTransactions.last?.amount, initialFeeFunds)
    }
    
    func test_tryToSwapBaseTokenWithoutFeeAccount() async throws {
        let account1 = try AccountBuilder.new()
        let account2 = try AccountBuilder.new()
        
        
        let client = KeetaClient(network: .test)
        let token = client.config.baseToken
        let offer = Proposal(amount: BigInt(1), token: token)
        let ask = Proposal(amount: Double(2), token: token)
        
        do {
            try await client.swap(account: account1, offer: offer, ask: ask, from: account2)
            XCTFail("Expected swap to fail as no fee account was explicitly provided")
            return
        } catch KeetaClientError.feeAccountMissing {
            // expected
        } catch {
            XCTFail("Unknown error: \(error)")
        }
    }
    
    func test_swapBaseToken() async throws {
        let account1 = try AccountBuilder.new()
        let account2 = try AccountBuilder.new()
        let feeAccount = try AccountBuilder.new()
        
        // Fund fee account
        try await fund(account: feeAccount, amount: 1_000_000)
        
        // Fund accounts
        try await fund(account: account1, amount: 1)
        try await fund(account: account2, amount: 2)
        
        let client = KeetaClient(network: .test)
        let token = client.config.baseToken
        let offer = Proposal(amount: BigInt(1), token: token)
        let ask = Proposal(amount: Double(2), token: token)
        
        try await client.swap(account: account1, offer: offer, ask: ask, from: account2, feeAccount: feeAccount)
        
        // Verify balances
        let account1Balance = try await client.balance(of: account1)
        XCTAssertEqual(account1Balance.balances[token.publicKeyString], 2)
        
        let account2Balance = try await client.balance(of: account2)
        XCTAssertEqual(account2Balance.balances[token.publicKeyString], 1)
    }
    
    func test_baseTokenMetaData() async throws {
        let client = KeetaClient(network: .test)
        let baseToken = try NetworkConfig.create(for: .test).baseToken
        
        let info = try await client.tokenInfo(for: baseToken)
        
        XCTAssertEqual(info.name, "KTA")
        XCTAssertEqual(info.description?.isEmpty, false)
        XCTAssertTrue(info.supply > 1_000_000_000)
        XCTAssertEqual(info.decimalPlaces, 9)
    }
    
    func test_createToken() async throws {
        let account = try AccountBuilder.new()
        
        // Fund account to cover network fees
        try await fund(account: account, amount: 2_000_000)
        
        let client = KeetaClient(network: .test, account: account)
        
        let supply = BigInt(100)
        let token = try await client.createToken(name: "TEST", supply: supply, decimals: 7, description: "Automated Swift Test")
        
        let info = try await client.tokenInfo(for: token)
        XCTAssertEqual(info.name, "TEST")
        XCTAssertEqual(info.description, "Automated Swift Test")
        XCTAssertEqual(info.supply, 100)
        XCTAssertEqual(info.decimalPlaces, 7)
        
        var tokenBalance = try await client.balance(of: token)
        XCTAssertEqual(tokenBalance.balances[token.publicKeyString], supply)
        
        let recipient = try AccountBuilder.new()
        let sendAmount = BigInt(10)
        try await client.send(
            amount: sendAmount, from: token, to: recipient, token: token, signer: account, feeAccount: account
        )
        
        tokenBalance = try await client.balance(of: token)
        XCTAssertEqual(tokenBalance.balances[token.publicKeyString], supply - sendAmount)
        
        let recipientBalance = try await client.balance(of: recipient)
        XCTAssertEqual(recipientBalance.balances[token.publicKeyString], sendAmount)
    }
    
    func test_demo() async throws {
        // 1. Generate a secure seed and create an account
        let seed = try SeedGenerator.generate()
        let account = try AccountBuilder.create(fromSeed: seed, index: 0)

        print("Public Key:", account.publicKeyString) // e.g., keeta_aabpd...csrqxi

        // 2. Initialize an account specific client for the test network
        let client = KeetaClient(network: .test, account: account)
        // Alternatively: let client = KeetaClient(network: .test)

        // 3. Get KTA test tokens from the faucet: https://faucet.test.keeta.com/
        
        // 4. Create a new token with an initial supply
        let newToken = try await client.createToken(name: "DEMO", supply: BigInt(100))

        // 5. Send some of minted tokens to the generated account
        // ℹ️ Token accounts can't sign transactions — use the owner (account) as signer
        try await client.send(amount: BigInt(10), from: newToken, to: account, token: newToken, signer: account)

        // 6. Check the account's balance
        let accountBalance = try await client.balance()
        print("Account Balance:", accountBalance.balances[newToken.publicKeyString] ?? "0") // 10

        // 7. Create a second account from the same seed with a different index
        let recipient = try AccountBuilder.create(fromSeed: seed, index: 1)

        // 8. Send tokens from the funded account to the new recipient
        try await client.send(amount: BigInt(5), to: recipient, token: newToken)

        // 9.Check the recipient's balance
        let recipientBalance = try await client.balance(of: recipient)
        print("Recipient Balance:", recipientBalance.balances[newToken.publicKeyString] ?? "0") // 5

        // 10. List account transactions
        let transactions = try await client.transactions()
        print("Transactions:", transactions) // [ -5 tokens sent, +10 tokens received ]

        // 11. Token swap between the two accounts
        try await client.swap(
            with: recipient,
            offer: .init(amount: BigInt(1), token: newToken),
            ask: .init(amount: BigInt(5), token: newToken)
        )
    }
    
    // MARK: Helper
    
    private func assert(
        _ transactions: [Transaction],
        _ expected: [ExpectedTransaction],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(transactions.count, expected.count, "Transactions count mismatch", file: file, line: line)
        
        for (index, expect) in expected.enumerated() {
            if transactions.indices.contains(index) {
                let transaction = transactions[index]
                XCTAssertTrue(expect.matches(transaction), "\(expect.pretty()) didn't match \(transaction.pretty())", file: file, line: line)
            } else {
                XCTFail("Transaction missing for \(expect.pretty())", file: file, line: line)
            }
        }
    }
    
    private func fund(account: Account, amount: BigInt) async throws {
        let config: NetworkConfig = try .create(for: .test)
        let api = try KeetaApi(config: config)
        try await api.send(amount: amount, from: wellFundedAccount, to: account, config: config)
    }
}

extension Transaction {
    fileprivate func pretty() -> String {
        "amount: \(amount.readable()), from: \(from.publicKeyString), to: \(to.publicKeyString), token: \(token.publicKeyString), created: \(created.readable()), external: \(String(describing: memo))"
    }
}
