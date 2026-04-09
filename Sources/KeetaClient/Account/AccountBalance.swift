import BigInt

public struct AccountBalance {
    public let account: String
    public let rawBalances: [String: BigInt]
    public let currentHeadBlock: String?

    public init(account: String, rawBalances: [String: BigInt], currentHeadBlock: String?) {
        self.account = account
        self.rawBalances = rawBalances
        self.currentHeadBlock = currentHeadBlock
    }
    
    public func canCover(fees: [String: BigInt]) -> Bool {
        !tokensCovering(fees: fees).isEmpty
    }
    
    public func tokensCovering(fees: [String: BigInt]) -> [String] {
        fees.compactMap { token, amount in
            rawBalances[token, default: 0] >= amount ? token : nil
        }
    }

    /// Returns the tokens that can cover the vote fees.
    /// When `supportedByAllVotes` is true, only considers tokens supported by every vote.
    public func tokensCovering(voteStaple: VoteStaple, baseToken: Account, supportedByAllVotes: Bool = true) -> [String] {
        tokensCovering(fees: voteStaple.totalFees(baseToken: baseToken, supportedByAllVotes: supportedByAllVotes))
    }

    public func selectFeeToken(for voteStaple: VoteStaple, baseToken: Account, preferredToken: Account? = nil, supportedByAllVotes: Bool = true) throws -> Account? {
        let fees = voteStaple.totalFees(baseToken: baseToken, supportedByAllVotes: supportedByAllVotes)
        return try selectFeeToken(for: fees, baseToken: baseToken, preferredToken: preferredToken)
    }
    
    /// Selects the best fee token: prefers `preferredToken`, falls back to any token that covers the fees.
    /// Returns `nil` when the chosen token is the base token (signalling "no override needed").
    /// Throws if no token can cover the fees.
    public func selectFeeToken(for fees: [String: BigInt], baseToken: Account, preferredToken: Account? = nil) throws -> Account? {
        let candidates = tokensCovering(fees: fees)
        let baseTokenKey = baseToken.publicKeyString
        let preferredTokenKey = (preferredToken ?? baseToken).publicKeyString

        let chosenKey: String
        if candidates.contains(preferredTokenKey) {
            chosenKey = preferredTokenKey
        } else if let fallbackKey = candidates.first {
            chosenKey = fallbackKey
        } else {
            throw BlockBuilderError.insufficientBalanceToCoverNetworkFees
        }

        if chosenKey == baseTokenKey { return nil }
        return try AccountBuilder.create(fromPublicKey: chosenKey)
    }
    
    public func balances(decimal: @escaping (String) -> Int?) -> [String: Double] {
        var balances = [String: Double]()
        for (token, rawAmount) in rawBalances {
            if let decimal = decimal(token) {
                balances[token] = rawAmount.fromRaw(decimals: decimal)
            }
        }
        return balances
    }
}
