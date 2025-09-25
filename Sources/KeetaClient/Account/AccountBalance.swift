import BigInt

public struct AccountBalance {
    public let account: String
    public let balances: [String: BigInt]
    public let currentHeadBlock: String?
    
    public func canCover(fees: [String: BigInt]) -> Bool {
        !fees.contains { feeToken, feeAmount in
            balances[feeToken, default: 0] < feeAmount
        }
    }
}
