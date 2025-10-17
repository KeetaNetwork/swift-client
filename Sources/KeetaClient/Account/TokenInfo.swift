public struct TokenInfo: Codable {
    public let address: String
    public let name: String
    public let description: String?
    public let supply: Double
    public let decimalPlaces: Int
    
    public init(address: String, name: String, description: String?, supply: Double, decimalPlaces: Int) {
        self.address = address
        self.name = name
        self.description = description
        self.supply = supply
        self.decimalPlaces = decimalPlaces
    }
}

public struct MetaData: Codable {
    public let decimalPlaces: Int
}
