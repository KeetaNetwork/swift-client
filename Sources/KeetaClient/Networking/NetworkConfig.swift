public struct NetworkConfig {
    public let network: NetworkAlias
    public let baseToken: Account
    public let baseTokenDecimals: Int
    public let fountain: Account?
    public let reps: [ClientRepresentative]
    
    public static func create(for network: NetworkAlias) throws -> Self {
        let baseToken = try AccountBuilder.generateBaseAddresses(for: network).baseToken
        
        let baseTokenDecimals = switch network {
        case .test: 9
        case .main: 18
        }
        
        let fountainSeed: String? = switch network {
        case .test: "0000000000000000000000000000000000000000000000000000000000000000"
        case .main: nil
        }
        
        let numberOfReps = 4
        
        return .init(
            network: network,
            baseToken: baseToken,
            baseTokenDecimals: baseTokenDecimals,
            fountain: try fountainSeed.map { try AccountBuilder.create(fromSeed: $0, index: 0xffffffff) },
            reps: (1...numberOfReps).map {
                .init(
                    address: network.keetaRepAddress(number: $0),
                    apiUrl: network.keetaRepApiBaseUrl(number: $0),
                    socketUrl: network.keetaRepSocketBaseUrl(number: $0))
            }
        )
    }
}
