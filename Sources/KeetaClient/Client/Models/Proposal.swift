import BigInt

public struct Proposal {
    public let amount: BigInt
    public let token: Account
    
    public init(amount: Double, token tokenPubKey: String) throws {
        self.init(amount: BigInt(amount), token: try AccountBuilder.create(fromPublicKey: tokenPubKey))
    }
    
    public init(amount: Double, token: Account) {
        self.init(amount: BigInt(amount), token: token)
    }
    
    public init(amount: BigInt, token: Account) {
        self.amount = amount
        self.token = token
    }
}
