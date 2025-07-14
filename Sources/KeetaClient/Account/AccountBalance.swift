import BigInt

public struct AccountBalance {
    public let account: String
    public let balances: [String: BigInt]
    public let currentHeadBlock: String?
}
