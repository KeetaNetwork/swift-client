import Testing
import BigInt
import KeetaClient

struct AccountBalanceTests {

    private let baseTokenKey = "keeta_base_token"
    private let tokenAKey = "keeta_token_a"

    // MARK: - tokensCovering

    @Test func tokensCovering_allCovered() {
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseTokenKey: 1000, tokenAKey: 500],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseTokenKey: 100, tokenAKey: 200]

        let result = balance.tokensCovering(fees: fees)

        #expect(Set(result) == Set([baseTokenKey, tokenAKey]))
    }

    @Test func tokensCovering_partiallyCovered() {
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseTokenKey: 1000, tokenAKey: 50],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseTokenKey: 100, tokenAKey: 200]

        let result = balance.tokensCovering(fees: fees)

        #expect(result == [baseTokenKey])
    }

    @Test func tokensCovering_noneCovered() {
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseTokenKey: 10],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseTokenKey: 100]

        let result = balance.tokensCovering(fees: fees)

        #expect(result.isEmpty)
    }

    @Test func tokensCovering_missingTokenDefaultsToZero() {
        let balance = AccountBalance(
            account: "test",
            rawBalances: [:],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseTokenKey: 1]

        let result = balance.tokensCovering(fees: fees)

        #expect(result.isEmpty)
    }

    @Test func tokensCovering_exactBalance() {
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseTokenKey: 100],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseTokenKey: 100]

        let result = balance.tokensCovering(fees: fees)

        #expect(result == [baseTokenKey])
    }

    // MARK: - selectFeeToken

    @Test func selectFeeToken_prefersBaseToken() throws {
        let baseToken = try AccountBuilder.create(fromPublicKey: "keeta_aabw4n2ptw7hpituggaqsoowv33vsk7pctc6iviyphhnxvoltiieksfmzqefsha")
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseToken.publicKeyString: 1000, tokenAKey: 500],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseToken.publicKeyString: 100, tokenAKey: 50]

        let result = try balance.selectFeeToken(for: fees, baseToken: baseToken)

        // nil means "use base token" (no override needed)
        #expect(result == nil)
    }

    @Test func selectFeeToken_fallsBackWhenBaseTokenInsufficient() throws {
        let baseToken = try AccountBuilder.create(fromPublicKey: "keeta_aabw4n2ptw7hpituggaqsoowv33vsk7pctc6iviyphhnxvoltiieksfmzqefsha")
        let tokenA = try AccountBuilder.create(fromPublicKey: "keeta_aab33wicxckpxfukeiulysf5k2wwbe6ifjcjjk7a5ptzobsw5rjow4m6hhhieuq")
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseToken.publicKeyString: 10, tokenA.publicKeyString: 500],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseToken.publicKeyString: 100, tokenA.publicKeyString: 50]

        let result = try #require(try balance.selectFeeToken(for: fees, baseToken: baseToken))

        #expect(result.publicKeyString == tokenA.publicKeyString)
    }

    @Test func selectFeeToken_usesPreferredWhenAffordable() throws {
        let baseToken = try AccountBuilder.create(fromPublicKey: "keeta_aabw4n2ptw7hpituggaqsoowv33vsk7pctc6iviyphhnxvoltiieksfmzqefsha")
        let preferred = try AccountBuilder.create(fromPublicKey: "keeta_aab33wicxckpxfukeiulysf5k2wwbe6ifjcjjk7a5ptzobsw5rjow4m6hhhieuq")
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseToken.publicKeyString: 1000, preferred.publicKeyString: 500],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseToken.publicKeyString: 100, preferred.publicKeyString: 50]

        let result = try #require(try balance.selectFeeToken(for: fees, baseToken: baseToken, preferredToken: preferred))

        #expect(result.publicKeyString == preferred.publicKeyString)
    }

    @Test func selectFeeToken_fallsBackWhenPreferredInsufficient() throws {
        let baseToken = try AccountBuilder.create(fromPublicKey: "keeta_aabw4n2ptw7hpituggaqsoowv33vsk7pctc6iviyphhnxvoltiieksfmzqefsha")
        let preferred = try AccountBuilder.create(fromPublicKey: "keeta_aab33wicxckpxfukeiulysf5k2wwbe6ifjcjjk7a5ptzobsw5rjow4m6hhhieuq")
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseToken.publicKeyString: 1000, preferred.publicKeyString: 1],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseToken.publicKeyString: 100, preferred.publicKeyString: 50]

        let result = try balance.selectFeeToken(for: fees, baseToken: baseToken, preferredToken: preferred)

        // nil means "use base token" (no override needed)
        #expect(result == nil)
    }

    @Test func selectFeeToken_returnsNilWhenPreferredIsBaseToken() throws {
        let baseToken = try AccountBuilder.create(fromPublicKey: "keeta_aabw4n2ptw7hpituggaqsoowv33vsk7pctc6iviyphhnxvoltiieksfmzqefsha")
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseToken.publicKeyString: 1000],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseToken.publicKeyString: 100]

        // Explicit base token as preferred should be normalized to nil
        let result = try balance.selectFeeToken(for: fees, baseToken: baseToken, preferredToken: baseToken)

        #expect(result == nil)
    }

    @Test func selectFeeToken_throwsWhenNothingAffordable() throws {
        let baseToken = try AccountBuilder.create(fromPublicKey: "keeta_aabw4n2ptw7hpituggaqsoowv33vsk7pctc6iviyphhnxvoltiieksfmzqefsha")
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseToken.publicKeyString: 1],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [baseToken.publicKeyString: 100]

        #expect(throws: BlockBuilderError.self) {
            try balance.selectFeeToken(for: fees, baseToken: baseToken)
        }
    }

    @Test func selectFeeToken_emptyFeesThrows() throws {
        let baseToken = try AccountBuilder.create(fromPublicKey: "keeta_aabw4n2ptw7hpituggaqsoowv33vsk7pctc6iviyphhnxvoltiieksfmzqefsha")
        let balance = AccountBalance(
            account: "test",
            rawBalances: [baseToken.publicKeyString: 1000],
            currentHeadBlock: nil
        )
        let fees: [String: BigInt] = [:]

        #expect(throws: BlockBuilderError.self) {
            try balance.selectFeeToken(for: fees, baseToken: baseToken)
        }
    }
}
