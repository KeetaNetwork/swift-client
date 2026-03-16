import BigInt

public struct ClientRepresentative {
    public let address: String
    public let apiUrl: String
    public let socketUrl: String
    public let weight: BigInt?
    
    public init(address: String, apiUrl: String, socketUrl: String, weight: BigInt? = nil) {
        self.address = address
        self.apiUrl = apiUrl
        self.socketUrl = socketUrl
        self.weight = weight
    }
    
    public var hasWeight: Bool {
        (weight ?? 0) > 0
    }
}

extension [ClientRepresentative] {
    var preferred: Element? {
        self.max { ($0.weight ?? 0) < ($1.weight ?? 0) }
    }
}
