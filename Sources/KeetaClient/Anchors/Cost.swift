import BigInt

public struct Cost: Codable {
    public let min: BigInt
    public let max: BigInt
    public let token: String
    
    public var noCost: Bool {
        min == 0 && max == 0
    }
}
