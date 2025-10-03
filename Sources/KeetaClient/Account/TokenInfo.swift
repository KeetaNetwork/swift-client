public struct TokenInfo: Codable {
    public let name: String
    public let description: String?
    public let supply: Double
    public let decimalPlaces: Int
}

public struct MetaData: Codable {
    public let decimalPlaces: Int
}
