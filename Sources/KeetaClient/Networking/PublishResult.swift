import BigInt

public struct PublishResult {
    public struct PaidFee {
        public let amount: BigInt
        public let to: String // public key
        public let token: String // public key
    }
    
    public let staple: VoteStaple
    public let fees: [PaidFee]
    public let feeBlockHash: String?
    
    public init(staple: VoteStaple, fees: [PaidFee], feeBlockHash: String?) {
        self.staple = staple
        self.fees = fees
        self.feeBlockHash = feeBlockHash
    }
    
    public var feeAmounts: [String: BigInt] {
        var result: [String: BigInt] = [:]
        for fee in fees {
            result[fee.token, default: 0] += fee.amount
        }
        return result
    }
}
