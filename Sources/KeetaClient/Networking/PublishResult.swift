import BigInt

public enum PublishResultError: Error {
    case feeBlockMissingInStaple
}

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
    
    public func lastBlockHash(for account: Account? = nil) throws -> String? {
        if let feeBlockHash {
            guard let feeBlock = staple.blocks.first(where: { $0.hash == feeBlockHash }) else {
                throw PublishResultError.feeBlockMissingInStaple
            }
            
            if account == nil || feeBlock.rawData.account.publicKeyString == account?.publicKeyString {
                return feeBlockHash
            }
        }
        
        if let account {
            return staple.blocks.last { $0.rawData.account.publicKeyString == account.publicKeyString }?.hash
        } else {
            return staple.blocks.last?.hash
        }
    }
}
