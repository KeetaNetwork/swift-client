import Foundation
import BigInt

public struct NetworkSendTransaction: Identifiable {
    public let id: String
    public let blockHash: String
    public let amount: BigInt
    public let from: Account
    public let to: Account
    public let token: Account
    public let isIncoming: Bool
    public let isNetworkFee: Bool
    public let created: Date
    public let memo: String?
}
