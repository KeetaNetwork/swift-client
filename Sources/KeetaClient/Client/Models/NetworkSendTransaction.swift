import Foundation
import BigInt

public struct NetworkSendTransaction: Identifiable, Codable, Equatable {
    public let id: String
    public let blockHash: String
    public let stapleHash: String
    public let amount: BigInt
    public let from: Account
    public let to: Account
    public let token: Account
    public let isIncoming: Bool
    public let isNetworkFee: Bool
    public let created: Date
    public let memo: String?
    
    public init(
        id: String,
        blockHash: String,
        stapleHash: String,
        amount: BigInt,
        from: Account,
        to: Account,
        token: Account,
        isIncoming: Bool,
        isNetworkFee: Bool,
        created: Date,
        memo: String?
    ) {
        self.id = id
        self.blockHash = blockHash
        self.stapleHash = stapleHash
        self.amount = amount
        self.from = from
        self.to = to
        self.token = token
        self.isIncoming = isIncoming
        self.isNetworkFee = isNetworkFee
        self.created = created
        self.memo = memo
    }
}
