import Foundation
import BigInt

public struct NetworkReceiveTransaction: Identifiable, Codable, Equatable {
    public let id: String
    public let blockHash: String
    public let stapleHash: String
    public let amount: BigInt
    public let from: Account
    public let to: Account
    public let token: Account
    public let created: Date
    
    public init(id: String, blockHash: String, stapleHash: String, amount: BigInt, from: Account, to: Account, token: Account, created: Date) {
        self.id = id
        self.blockHash = blockHash
        self.stapleHash = stapleHash
        self.amount = amount
        self.from = from
        self.to = to
        self.token = token
        self.created = created
    }
}
