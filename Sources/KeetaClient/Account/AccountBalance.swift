import BigInt

public struct AccountBalance {
    public let account: String
    public let rawBalances: [String: BigInt]
    public let currentHeadBlock: String?
    
    public func canCover(fees: [String: BigInt]) -> Bool {
        !fees.contains { feeToken, feeAmount in
            rawBalances[feeToken, default: 0] < feeAmount
        }
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
