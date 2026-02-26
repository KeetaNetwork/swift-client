import BigInt

public enum AdjustMethod: Int {
    case add
    case subtract
    case set
    
    public var value: BigInt {
        BigInt(rawValue)
    }
}
