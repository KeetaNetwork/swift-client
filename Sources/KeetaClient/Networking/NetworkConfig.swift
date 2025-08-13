public struct NetworkConfig {
    public let networkAlias: NetworkAlias
    public let networkID: NetworkID
    public let baseToken: Account
    public let fountain: Account
    public let reps: [ClientRepresentative]
    
    public static func create(for network: NetworkAlias) throws -> Self {
        let networkID: NetworkID = switch network {
        case .test: 0x54455354 // 1413829460
        }
        
        let baseTokenPubKey = switch network {
        case .test: "keeta_anyiff4v34alvumupagmdyosydeq24lc4def5mrpmmyhx3j6vj2uucckeqn52"
        }
        
        let fountainSeed = switch network {
        case .test: "0000000000000000000000000000000000000000000000000000000000000000"
        }
        
        let numberOfReps = 4
        
        return .init(
            networkAlias: network,
            networkID: networkID,
            baseToken: try AccountBuilder.create(fromPublicKey: baseTokenPubKey),
            fountain: try AccountBuilder.create(fromSeed: fountainSeed, index: 0xffffffff),
            reps: (1...numberOfReps).map {
                .init(
                    address: network.keetaRepAddress(number: $0),
                    apiUrl: network.keetaRepApiBaseUrl(number: $0),
                    socketUrl: network.keetaRepSocketBaseUrl(number: $0))
            }
        )
    }
}
