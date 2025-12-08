public struct NetworkConfig {
    public let network: NetworkAlias
    public let baseToken: Account
    public let baseTokenDecimals: Int
    public let fountain: Account?
    public let reps: [ClientRepresentative]
    
    public static func create(for network: NetworkAlias) throws -> Self {
        let baseTokenPubKey = switch network {
        case .test: "keeta_anyiff4v34alvumupagmdyosydeq24lc4def5mrpmmyhx3j6vj2uucckeqn52"
        case .main: "keeta_anqdilpazdekdu4acw65fj7smltcp26wbrildkqtszqvverljpwpezmd44ssg"
        }
        
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
            baseToken: try AccountBuilder.create(fromPublicKey: baseTokenPubKey),
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
