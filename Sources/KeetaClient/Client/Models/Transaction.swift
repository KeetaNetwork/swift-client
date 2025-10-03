import Foundation
import BigInt

public struct Transaction {
    public let amount: BigInt
    public let from: Account
    public let to: Account
    public let token: Account
    public let isNetworkFee: Bool
    public let created: Date
    public let memo: String?
}
