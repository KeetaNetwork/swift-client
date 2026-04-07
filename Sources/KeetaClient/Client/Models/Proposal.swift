public struct Proposal {
    public let amount: TokenAmount
    public let token: Account
    
    public init(amount: TokenAmount, token tokenPubKey: String) throws {
        self.init(amount: amount, token: try AccountBuilder.create(fromPublicKey: tokenPubKey))
    }

    public init(amount: TokenAmount, token: Account) {
        self.amount = amount
        self.token = token
    }
}
