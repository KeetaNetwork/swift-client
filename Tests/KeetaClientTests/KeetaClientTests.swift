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
        
        func matches(_ transaction: NetworkSendTransaction) -> Bool {
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
    
    func test_deterministicTransactionIds() async throws {
        let client = KeetaClient(network: .test, account: wellFundedAccount)
        
        let all1 = try await client.transactions()
        let all2 = try await client.transactions()
        
        XCTAssertEqual(all1, all2)
    }
    
    func test_transactionsPagination() async throws {
        let client = KeetaClient(network: .test, account: wellFundedAccount)
        
        let all = try await client.transactions(limit: 5)
        
        guard all.count >= 5 else {
            XCTFail("Received less transactions than expected: \(all.count)")
            return
        }
        
        let subPage = try await client.transactions(limit: 3, startBlocksHash: all[1].stapleHash)
        
        XCTAssertTrue(subPage.isSubsequence(of: all), "Expected \(subPage) to be a subset of \(all)")
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
        XCTAssertEqual(feeTransactions.count(where: { $0.send?.amount == 110_100 }), expectedFeesPaidTransferCount)
        XCTAssertEqual(feeTransactions.count(where: { $0.send?.isNetworkFee == true }), expectedFeesPaidTransferCount)
        XCTAssertEqual(feeTransactions.count(where: { $0.send?.from.publicKeyString == feeAccount.publicKeyString }), expectedFeesPaidTransferCount)
        XCTAssertEqual(feeTransactions.last?.send?.amount, initialFeeFunds)
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
        XCTAssertEqual(account1Balance.rawBalances[token.publicKeyString], 2)
        
        let account2Balance = try await client.balance(of: account2)
        XCTAssertEqual(account2Balance.rawBalances[token.publicKeyString], 1)
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
    
    func test_tokenIcon() async throws {
        let account = try AccountBuilder.new()

        try await fund(account: account, amount: 2_000_000)
        
        let client = KeetaClient(network: .test, account: account)
        
        let localImageUrl = Bundle.module.url(forResource: "cheeta", withExtension: "png")!
        let localImage = KeetaImage(data: try .init(contentsOf: localImageUrl))!
        let remoteUrl = URL(string: "https://keeta.com/assets/logo-cheeta-black.png")!
        let dataUrl = URL(string: "data:image/jpeg;base64,/9j/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAEAAAAAAAD/2wCEAAEBAQEBAQEBAQEBAQECAgMCAgICAgQDAwIDBQQFBQUEBAQFBgcGBQUHBgQEBgkGBwgICAgIBQYJCgkICgcICAgBAQEBAgICBAICBAgFBAUICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICP/CABEIAEAAQAMBIgACEQEDEQH/xAAyAAEAAgIDAQAAAAAAAAAAAAAACAkGCgIEBwUBAQEBAQEAAAAAAAAAAAAAAAABAgME/9oADAMBAAIQAxAAAADVXD0AAAZzdpCaCbN5X0IMV7kt7uKusYSD2FbP2sC048s3XbfrthVNlz7sH60uu37n4YKAAAB//8QANRAAAQMDAwMCAwUIAwAAAAAAAQIDBAUGBwgREgAJMRMhFEFRChAyQGEVFhciIyQzYkNxcv/aAAgBAQABPwD8hYWMMlZUuWBZuMce3zkS7JTgaj02iUl+bIdUTsAENJUR/wBnYD5kdWj2NqjiGzqRlXuf6t8KdvOxpjfrQ6BOkN1u7qkjyA1T2HOCT8ilBfWk/iQD7dKx19m2oi/3dmaje5le80f01XDT7aiR4XLfYuJjuQUucfntwJ26ndlzEeqC3qrePac104y1fTobBlS8dXWlFtXhFb232Q26G0O7eOTjUdBPsHD1Ve3Vr7ot8fw3qOivVE1e5eEdEFFkz3UurJ2BTJbbVHKCf+QOFG3vvt79ZJ+z3Wg9jy/8L6bdRNUzP3N8cUGgXLkXG76IsKkPxqmlSkx6XJdS3xdaShSgt15YcHDmGS+3tkfG9/4gvm58ZZTs248e5CospUKq0arxVRpcB4AHi42r3G4UlQUN0qSpKkkpIJ6pvda1025RHqHZGYo+O2nEem5KoNFixpih+j6krUk/qnY/Qjq873vTI901S+Mh3ddF+XrNVymVetVB6dNlH/d95SlkfQb7D5AdaF9I0DVZjLW/Up8EUdGNMaSr+TcTiyhiE4yHVIjOk/y7u+gvinyQlzztuKFXq3bdYpFz23WKzbVyQnEyINQgSnIsuA6PcKZfbKVtqH1SQeqL3k+61Ht6Hjyj64M+TY0jaLFRziy6m8T7BDUpUdcta/kNllf69TdJ/dhqlUqOqWoaf9fcu5XXBWZV9uUWuCqOLQAoSlStvilcQhJC9iEhI8AAdd1ex7uzl2vtI2urWpj9WA+4IirMWH6U/wBGLUcuW0ltS2qrKpwIdjvtJPrHmlJRydBCUSGEp+5YWW3A1/l4nh/629vP67dZuxLcGojtVWJjTsU2JjK6NNtYjwV51t6jTwckz66hLf8AbVZEhY9RrkgKcQFhawlPopMYkG2Oy1jrTPQadk7u66v8eaQKA62mVGx3bMtqvXxW0eeCGWQ62wVe45NtyQD+JSPPUzvA6YdG8SdaXaP0N2JiKrhsxl5bycyK7d88ePVaaUtYj7+54qeUj392E+Oh3me6eL7byKdc+dzXUv8AriKZkf8AZZO+/E0z0fhCj/UtdaiNS+edWWSqjl7UXlG6MsZCkthj46puJCYjAO4jxWG0pZjMAkkNNISnckkEkk/djy5rftC6IlduayaTkGlNNrBpk5ZSy64QOKlEb+CPBBB38dUzuzaw8fUqNbuna6LY0uW6yU8WrHo8eNIdCTuEuSHELKk/UBKQfffcE9Re8vhDVlQodm923RDj3U5U2IfwcPKFjIbt28oKQDw5qbU2h1IJ/C26y2NyfRV4MtyM7KlOw4q4UNTq1Msqd9VTLZUSlBXsOZSnYFWw3232G+35T//EABQRAQAAAAAAAAAAAAAAAAAAAED/2gAIAQIBAT8AB//EABoRAAICAwAAAAAAAAAAAAAAAAABESACECH/2gAIAQMBAT8Ap0SHInOoYsbf/9k=")!
        
        let icons: [TokenIcon] = [
            .raw(try Data(contentsOf: localImageUrl)),
            .remote(remoteUrl),
            .data(dataUrl)
        ]
        
        for icon in icons {
            let token = try await client.createToken(name: "ICO", supply: BigInt(1), icon: icon)
            let info = try await client.tokenInfo(for: token)
            
            switch info.icon {
            case .remote(let url):
                XCTAssertEqual(url, remoteUrl, "Token icon url mismatch \(token.publicKeyString)")
            case .data(let url):
                XCTAssertEqual(url, dataUrl, "Token icon url mismatch \(token.publicKeyString)")
            case .raw(let data):
                let image = try XCTUnwrap(KeetaImage(data: data))
                // Verify the resolution is identical, can't easily compare the image itself reliably otherwise
                XCTAssertEqual(image.size, localImage.size, "Token icon size mismatch \(token.publicKeyString)")
            case nil:
                XCTFail("Missing icon for token \(token.publicKeyString)")
            }
        }
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
        XCTAssertEqual(tokenBalance.rawBalances[token.publicKeyString], supply)
        
        let recipient = try AccountBuilder.new()
        let sendAmount = BigInt(10)
        let options = Options(signer: account, feeAccount: account)
        try await client.send(amount: sendAmount, from: token, to: recipient, token: token, options: options)
        
        tokenBalance = try await client.balance(of: token)
        XCTAssertEqual(tokenBalance.rawBalances[token.publicKeyString], supply - sendAmount)
        
        let recipientBalance = try await client.balance(of: recipient)
        XCTAssertEqual(recipientBalance.rawBalances[token.publicKeyString], sendAmount)
    }
    
    func test_recoverAccount() async throws {
        let account = try AccountBuilder.new()
        let recipient = try AccountBuilder.new()
        
        let client = KeetaClient(network: .test, account: account)
        
        // Fund account to cover network fees
        try await fund(account: account, amount: 2_000_000)
        
        // Get account stuck by requesting temporary votes for conflicting blocks
        
        // Request temporary votes for first block
        let send = try SendOperation(amount: 1, to: recipient, token: client.config.baseToken)
        let sendBlock1 = try BlockBuilder()
            .start(from: nil, config: client.config)
            .add(account: account)
            .add(operation: send)
            .seal()

        let temporaryVotes = try await client.api.votes(for: [sendBlock1], type: .temporary())
        
        // Try to get new temporary votes for a different block
        let anotherSendBlock = try BlockBuilder()
            .start(from: nil, config: client.config)
            .add(account: account)
            .add(operation: send)
            .seal()
        
        do {
            _ = try await client.api.votes(for: [anotherSendBlock], type: .temporary())
            XCTFail("Shouldn't get conflicting temporary votes")
            return
        } catch RequestError<KeetaErrorResponse>.error(_, let error) {
            XCTAssertEqual(error.code, .successorVoteExists) // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Recover blocks to publish
        let ready = try await client.recoverAccount(publish: false)
        if case .readyToPublish(let recoveredBlocks, let recoveredTemporaryVotes) = ready {
            XCTAssertEqual(recoveredBlocks.count, 2) // send block + fee block
            XCTAssertTrue(recoveredBlocks.map(\.hash).contains(sendBlock1.hash))
            XCTAssertEqual(Set(recoveredTemporaryVotes.map(\.hash)), Set(temporaryVotes.map(\.hash)))
        } else {
            XCTFail()
            return
        }
        
        // Recover account
        _ = try await client.recoverAccount(publish: true)
        
        // Verify published block can be fetched from the network
        _ = try await client.api.block(for: sendBlock1.hash)
    }
    
    func test_basicPermissionFlow() async throws {
        let owner = try AccountBuilder.new()
        let principal = try AccountBuilder.new()
        
        let client = KeetaClient(network: .test, account: owner)
        
        // Fund account to cover network fees
        try await fund(account: owner, amount: 10_000_000)
        
        // Grant permission
        try await client.grantPermissions([.SEND_ON_BEHALF], to: principal)
        
        let expectedPermission = Permission(baseFlags: [.ACCESS, .SEND_ON_BEHALF])
        
        // Verify owner & principal
        let ownerPermissionsGranted = try await client.api.grantedPermissions(of: owner)
        let principalPermissionsGranted = try await client.api.permissionsReceived(for: principal)
        
        XCTAssertEqual(ownerPermissionsGranted.count, 1)
        XCTAssertEqual(ownerPermissionsGranted.first?.permission, expectedPermission)
        XCTAssertEqual(principalPermissionsGranted.count, 1)
        XCTAssertEqual(principalPermissionsGranted.first?.permission, expectedPermission)
        
        // Revoke permission
        try await client.removePermissions([.ACCESS, .SEND_ON_BEHALF], from: principal)
        
        // Verify owner & principal
        let ownerPermissionsRevoked = try await client.api.grantedPermissions(of: owner)
        let principalPermissionsRevoked = try await client.api.permissionsReceived(for: principal)
        
        XCTAssertEqual(ownerPermissionsRevoked, [])
        XCTAssertEqual(principalPermissionsRevoked, [])
    }
    
    func test_permissions() async throws {
        let account = try AccountBuilder.new()
        
        let client = KeetaClient(network: .test, account: account)
        
        // Fund account to cover network fees
        try await fund(account: account, amount: 10_000_000)
        
        let account1 = try AccountBuilder.new()
        let account2 = try AccountBuilder.new()
        let account3 = try AccountBuilder.new()
        
        try await client.grantPermissions([.SEND_ON_BEHALF], to: account1)
        try await client.grantPermissions([.MANAGE_CERTIFICATE], to: account2)
        try await client.grantPermissions([.UPDATE_INFO, .PERMISSION_DELEGATE_ADD], to: account3)
        
        let permissions = try await client.api.grantedPermissions(of: account)
        
        XCTAssertEqual(permissions.count, 3)
        
        let accounts: [String: Set<Permission.BaseFlag>] = [
            account1.publicKeyString: [.ACCESS, .SEND_ON_BEHALF],
            account2.publicKeyString: [.ACCESS, .MANAGE_CERTIFICATE],
            account3.publicKeyString: [.ACCESS, .UPDATE_INFO, .PERMISSION_DELEGATE_ADD]
        ]
        for permission in permissions {
            guard let matched = accounts[permission.principal.publicKeyString] else {
                XCTFail("Unknown principal: \(permission.principal.publicKeyString)")
                continue
            }
            XCTAssertEqual(permission.target?.publicKeyString, account.publicKeyString)
            XCTAssertEqual(permission.permission, .init(baseFlags: matched, external: 0))
        }
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
        let options = Options(signer: account)
        try await client.send(amount: BigInt(10), from: newToken, to: account, token: newToken, options: options)

        // 6. Check the account's balance
        let accountBalance = try await client.balance()
        print("Account Balance:", accountBalance.rawBalances[newToken.publicKeyString] ?? "0") // 10

        // 7. Create a second account from the same seed with a different index
        let recipient = try AccountBuilder.create(fromSeed: seed, index: 1)

        // 8. Send tokens from the funded account to the new recipient
        try await client.send(amount: BigInt(5), to: recipient, token: newToken)

        // 9.Check the recipient's balance
        let recipientBalance = try await client.balance(of: recipient)
        print("Recipient Balance:", recipientBalance.rawBalances[newToken.publicKeyString] ?? "0") // 5

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
        _ transactions: [NetworkTransaction],
        _ expected: [ExpectedTransaction],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(transactions.count, expected.count, "Transactions count mismatch", file: file, line: line)
        
        for (index, expect) in expected.enumerated() {
            if transactions.indices.contains(index) {
                let transaction = transactions[index]
                if let send = transaction.send {
                    XCTAssertTrue(expect.matches(send), "\(expect.pretty()) didn't match \(send.pretty())", file: file, line: line)
                } else {
                    XCTFail("Invalid transaction type: \(transaction)", file: file, line: line)
                }
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

extension NetworkSendTransaction {
    fileprivate func pretty() -> String {
        "amount: \(amount.readable()), from: \(from.publicKeyString), to: \(to.publicKeyString), token: \(token.publicKeyString), created: \(created.readable()), external: \(String(describing: memo))"
    }
}
