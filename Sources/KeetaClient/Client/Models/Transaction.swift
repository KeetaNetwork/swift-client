import Foundation
import BigInt

public struct Transaction {
    public let amount: BigInt
    public let from: Account
    public let to: Account
    public let token: Account
    public let created: Date
    public let memo: String?
}
